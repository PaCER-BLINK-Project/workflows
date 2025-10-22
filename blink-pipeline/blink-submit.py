#!/usr/bin/env python3
from astropy.io import fits
import argparse
from itertools import product
import os

# Script to tile an observation's FoV in smaller chunks
# for processing with the BLINK pipeline.

def get_info_from_metafits(metafits_file):
    hdus = fits.open(metafits_file)
    ra = hdus[0].header['RA']
    dec = hdus[0].header['DEC']
    flagged_antennas = set([row['ANTENNA'] for row in hdus[1].data if row['FLAG'] > 0])
    n_antennas = len(hdus[1].data) // 2
    project = hdus[0].header['PROJECT']
    return project, ra, dec, n_antennas, flagged_antennas

"""
if ! [ -e $OUTPUT_DIR ]; then
  mkdir -p $OUTPUT_DIR
  # tells Lustre FS to only use the Flash pool (SSDs)
  # lfs setstripe -p flash $OUTPUT_DIR
fi
"""

GLOBAL_CONFIG = {
    "data_path_prefix" : f"/scratch/{os.getenv('PAWSEY_PROJECT')}/{os.getenv('USER')}"
    # TODO add default pixsizes for different types of observations
}

SEARCH_PARAMETERS = {
    'extended' : {

    },

    'SMART' : {
        'oversampling' : 1,
        'imgsize' : 256,
        'dm_range' : [
            '10:100:1',
            '101:200:1',
            '201:300:1',
            '301:350:1',
            '351:400:1',
            '401:450:1',
            '451:500:1'
        ],
        'duration' : 1196,
        'offsets' : [0, 1170, 2340, 3510, 4680], # allow 30 seconds overlap
    }
}

# TODO set proper output log directory / policy
# TODO print job cost prediction

def submit_job(observation_id : int, n_antennas : int, image_size : int,
        ra : float, dec : float, reorder : bool, start_offset : int,
        duration : int, time_res : float, freq_avg_factor : int,
        oversampling : float, average_images : bool, flagging_threshold : float,
        flagged_antennas : list, dedisp : str, snr : float, dyspec : str,
        slm_partition : str, slm_account : str, slm_time : str,
        dir_postfix : str, dry_run : bool):

    # TODO: make sure the following paths exist
    # Move FS operations outside?
    observation_path = f"{GLOBAL_CONFIG['data_path_prefix']}/{observation_id}"
    combined_files_path = f"{observation_path}/combined"
    metafits_file = f"{observation_path}/{observation_id}.metafits"
    # find the solution file
    bin_filenames = [x for x in os.listdir(observation_path) if x.endswith(".bin")]
    if len(bin_filenames) == 0:
        raise Exception("No .bin file found in the observation's directory.")
    solutions_file = f"{observation_path}/{bin_filenames[0]}"
    output_dir = f"{observation_path}_output_ra{ra:.3f}_dec{dec:.3f}"
    if dir_postfix is not None: output_dir += f"_{dir_postfix}"
    slurm_out_file = f"{output_dir}/slurm-%A.out"
    
    if dedisp is not None:
        job_title = f"BLINK Dedispersion - {observation_id} -  RA {ra:.3f} DEC {dec:.3f} - DM range {dedisp}"
    elif dyspec is not None:
        job_title = f"BLINK Dynamic Spectrum - {observation_id} - {dyspec}"
    else:
        job_title = f"BLINK Imaging - {observation_id}"
    
    slurm_sbatch_args = f"--gres=gpu:8 --partition={slm_partition} --job-name=\"{job_title}\" " \
        f"--account={slm_account}-gpu --output={slurm_out_file} --time={slm_time}"

    blink_line = f"blink_pipeline -R {n_antennas} -c {freq_avg_factor} -t {time_res}s -o {output_dir} " \
        f"-n {image_size} -O {oversampling} -M {metafits_file} {'-r' if reorder else ''} " \
        f"-s {solutions_file} -b 0 -I {combined_files_path} -X {start_offset}"
    
    if average_images:
        blink_line += " -u"
    
    if flagging_threshold > 0:
        blink_line += f" -f {flagging_threshold}"

    if duration >= 0:
        blink_line += f" -Q {duration}"
    
    if ra is not None and dec is not None:
        blink_line +=  f" -P {ra},{dec}"
    
    if len(flagged_antennas) > 0:
        blink_line += f' -A {",".join(str(x) for x in flagged_antennas)}'
    
    if dedisp is not None:
        tokens = dedisp.split(':')
        if len(tokens) != 3:
            raise ValueError(f"Dedispersion range is malformed: {dedisp}")
        postfix = f"dm_range_{dedisp.replace(':', '_')}"
        blink_line += f' -D {dedisp} -S {snr} -p {postfix} '

    if dyspec is not None:
        blink_line += f' -d {dyspec} '
        
    
    wrap_command  = "module load blink-pipeline-gpu/main ; "
    wrap_command += f"{blink_line} ;"
    
    submit_command_line = f"sbatch {slurm_sbatch_args} --wrap \"{wrap_command}\""
    print("Submitting BLINK job with the following command:\n" + submit_command_line)

    if not dry_run:
        os.system(submit_command_line)



def compute_tiling(pc_ra_deg, pc_dec_deg, img_size, tile_size, pix_size_deg):
    img_pc_pixel_coord = int(img_size / 2)
    # compute number of tiles
    n_tiles = int((img_size + tile_size - 1)  / tile_size)

    # pixel (0, 0) RA, DEC - it is going to be our reference point
    px0_ra = pc_ra_deg - img_pc_pixel_coord * pix_size_deg
    px0_dec = pc_dec_deg + img_pc_pixel_coord * pix_size_deg
    

    def compute_tile_pc_coord(t_x, t_y):
        tile_pc_pixel_x = t_x * tile_size + int(tile_size / 2)
        tile_pc_pixel_y = t_y * tile_size + int(tile_size / 2)
        tile_pc_ra = px0_ra + tile_pc_pixel_x * pix_size_deg
        tile_pc_dec = px0_dec - tile_pc_pixel_y * pix_size_deg
        return tile_pc_ra, tile_pc_dec

    tile_side_coord = list(range(n_tiles))
    coords = [compute_tile_pc_coord(x, y) for x, y in product(tile_side_coord, tile_side_coord)]
    return coords



if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    # Observation information
    parser.add_argument("--obsid", type=str, help="Observation ID", default="1192477696")
    parser.add_argument("--pixsize", type=float, default=None, help="Size of a pixel (side) in degrees.")
    parser.add_argument("--mwax", action='store_true', help="It is an MWAX observation.")
    parser.add_argument("--no-flags", action='store_true', help="Do NOT flag bad tiles.")

    # BLINK pipeline args
    parser.add_argument("--offset", type=int, default=0, help="Number of seconds to skip from the start of the observations.")
    parser.add_argument("--duration", type=int, default=-1, help="Number of seconds to process. Default: all seconds.")
    parser.add_argument("--tilesize", type=int, default=-1, help="Enable FoV tiling by specifying the size of the tile (side).")
    parser.add_argument("--imgsize", type=int, default=256, help="Size of the image (side, e.g. 4096)")
    parser.add_argument("--centre", type=str, default=None, help="Specify phase centre coordinates in RA,DEC degrees.")
    parser.add_argument("--snr", type=float, default=10, help="SNR threshold for detections in dedispersion mode.")
    parser.add_argument("--time-res", type=float, default=0.02, help="Time resolution.")
    parser.add_argument("--freq-avg", type=int, default=4, help="Frequency averaging factor.")
    parser.add_argument("--oversampling", type=float, default=2, help="Imaging oversampling factor.")
    parser.add_argument("--avg-images", action='store_true', help="Enable image averaging across the entire coarse channel and second.")
    parser.add_argument("--img-flag", type=float, default=8, help="Image RMS flagging threshold.")

    # execution modes
    parser.add_argument("--dyspec", type=str, default=None, help="Enable dynamic spectrum mode by passing pixels coordinates (x1,y1:x2,y2:x3,y3).")
    parser.add_argument("--dedisp", type=str, default=None, help="Enable dedispersion mode by passing the DM range in the format min:max:step (e.g. 50:60:1)")
    parser.add_argument("--dry-run", action='store_true', help="Do not actually submit jobs.")
    parser.add_argument("--dir-postfix", type=str, default=None, help="Adds the specified postfix to the output directory.")
    parser.add_argument("--search", action='store_true', help="Run an FRB search over the entire parameter space.")
    parser.add_argument("--time-bins", type=int, nargs='*', help="Limit the search to the specified time intevals. Intervals are specified with 0-based indexing.")
    parser.add_argument("--dm-bins", type=int, nargs='*', help="Limit the search to the specified DM intevals. Intervals are specified with 0-based indexing.")
    

    # SLURM configuratino options
    parser.add_argument("--partition", default="gpu", type=str, help="Setonix GPU partition where to submit the job")
    parser.add_argument("--account", default="pawsey1154", type=str, help="Setonix account billed for the job.")
    parser.add_argument("--time", type=str, default="24:00:00", help="Slurm job walltime.")

    # parser.add_argument("--overlap")
    args = vars(parser.parse_args())
    
    tile_size = args['tilesize']
    img_size = args['imgsize']
    pix_size_deg = args['pixsize']

    # TODO: compute image size given pixsize

    metafits_file = f"{GLOBAL_CONFIG['data_path_prefix']}/{args['obsid']}/{args['obsid']}.metafits"
    project, pc_ra_deg, pc_dec_deg, n_antennas, flagged_antennas = get_info_from_metafits(metafits_file)
    
    if args['no_flags']:
        flagged_antennas = []
    
    if args['centre'] is not None:
        tokens = args['centre'].split(',')
        if len(tokens) != 2: raise ValueError("Phase centre spec is malformed.")
        pc_ra_deg, pc_dec_deg = float(tokens[0]), float(tokens[1])
    

    if args['search']:
        if project == 'G0057':
            offsets = SEARCH_PARAMETERS['SMART']['offsets']
            dm_ranges =  SEARCH_PARAMETERS['SMART']['dm_range']
            selected_time_bins = args["time_bins"]
            selected_dm_bins = args["dm_bins"]

            if len(selected_time_bins) == 0:
                selected_time_bins = list(range(len(offsets)))
            if len(selected_dm_bins) == 0:
                selected_dm_bins = list(range(len(dm_ranges)))

            for j, dm_range in enumerate(dm_ranges):
                if j not in selected_dm_bins: continue
                for i, offset in enumerate(offsets):
                    if i not in selected_time_bins: continue
                    duration = -1 if (i == len(offsets) - 1) else SEARCH_PARAMETERS['SMART']['duration']
                    submit_job(args["obsid"], n_antennas, SEARCH_PARAMETERS['SMART']['imgsize'], pc_ra_deg, pc_dec_deg, 
                        not args["mwax"],
                        offset, duration, args["time_res"], args["freq_avg"], SEARCH_PARAMETERS['SMART']['oversampling'],
                        args["avg_images"], args["img_flag"], flagged_antennas, dm_range,
                        args["snr"], args["dyspec"], args["partition"], args["account"], args["time"],
                        args["dir_postfix"], args["dry_run"])
            
        # TODO: add estimate of cost in SU in printed summary
    else:

        submit_job(args["obsid"], n_antennas, args["imgsize"], pc_ra_deg, pc_dec_deg, not args["mwax"],
            args["offset"], args["duration"], args["time_res"], args["freq_avg"], args["oversampling"],
            args["avg_images"], args["img_flag"], flagged_antennas, args["dedisp"],
            args["snr"], args["dyspec"], args["partition"], args["account"], args["time"],
            args["dir_postfix"], args["dry_run"])
