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
    return ra, dec, flagged_antennas

"""
if ! [ -e $OUTPUT_DIR ]; then
  mkdir -p $OUTPUT_DIR
  # tells Lustre FS to only use the Flash pool (SSDs)
  # lfs setstripe -p flash $OUTPUT_DIR
fi
"""

GLOBAL_CONFIG = {
    'data_path_prefix' : '/scratch/$PAWSEY_PROJECT/$USER'
    # TODO add default pixsizes for different types of observations
}


def submit_job(observation_id : int, solution_id : int, image_size : int,
        ra : float, dec : float, reorder : bool, start_offset : int,
        duration : int, flagged_antennas : list, dedisp : str, snr : float,
        dyspec : str,
        slm_partition : str, slm_account : str, slm_time : str):

    observation_path = f"{GLOBAL_CONFIG['data_path_prefix']}/{observation_id}"
    combined_files_path = f"{observation_path}/combined"
    metafits_file = f"{observation_path}/{observation_id}.metafits"
    solutions_file = f"{observation_path}/{solution_id}.bin"
    output_dir = f"{observation_path}_output_ra{ra:.3f}_dec{dec:.3f}"
    slurm_out_file = f"{output_dir}"

    slurm_sbatch_args = f"--gres=gpu:8 --partition={slm_partition} " \
        f"--account={slm_account}-gpu --output={slurm_out_file} --time={slm_time}"

    blink_line=f"blink_pipeline -u -c 4 -t 1s -o {output_dir} " \
        f"-n {image_size}  -M {metafits_file} {"-r" if reorder else ""} " \
        f"-s {solutions_file} -b 0 -I {combined_files_path} -X {start_offset} "
    
    if duration >= 0:
        blink_line += f" -Q {duration} "
    
    if ra is not None and dec is not None:
        blink_line +=  f" -P {ra},{dec} "
    
    if len(flagged_antennas) > 0:
        blink_line += f' -A {",".join(str(x) for x in flagged_antennas)} '
    
    if dedisp is not None:
        tokens = dedisp.split(':')
        if len(tokens) != 3:
            raise ValueError(f"Dedispersion range is malformed: {dedisp}")
        blink_line += f' -D {dedisp} -S {snr} '

    if dyspec is not None:
        blink_line += f' -d {dyspec} '
        
    
    wrap_command  = "module load blink-pipeline-gpu/main ;"
    wrap_command += f"{blink_line} ;"
    
    submit_command_line = f"sbatch {slurm_sbatch_args} --wrap \"{wrap_command}\""
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
    parser.add_argument("--calid", type=str, help="Calibration solution ID", default="1192467680")
    parser.add_argument("--pixsize", type=float, default=None, help="Size of a pixel (side) in degrees.")
    parser.add_argument("--mwax", action='store_true', help="It is an MWAX observation.")
    parser.add_argument("--no-flags", action='store_true', help="Do NOT flag bad tiles.")

    # BLINK pipeline args
    parser.add_argument("--offset", type=int, default=0, help="Number of seconds to skip from the start of the observations.")
    parser.add_argument("--duration", type=int, default=-1, help="Number of seconds to process. Default: all seconds.")
    parser.add_argument("--tilesize", type=int, default=-1, help="Enable FoV tiling by specifying the size of the tile (side).")
    parser.add_argument("--imgsize", type=int, required=True, help="Size of the image (side, e.g. 4096)")
    parser.add_argument("--dyspec", type=str, default=None, help="Enable dynamic spectrum mode by passing pixels coordinates (x1,y1:x2,y2:x3,y3).")
    parser.add_argument("--dedisp", type=str, default=None, help="Enable dedispersion mode by passing the DM range in the format min:max:step (e.g. 50:60:1)")

    # SLURM configuratino options
    parser.add_argument("--partition", default="gpu", type=str, help="Setonix GPU partition where to submit the job")
    parser.add_argument("--account", default="pawsey1154", type=str, help="Setonix account billed for the job.")
    parser.add_argument("--time", type=str, default="24:00:00", help="Slurm job walltime.")

    # parser.add_argument("--overlap")
    parser.add_argument("metafits", type=str, help="Path to the metafits file.")
    args = vars(parser.parse_args())
    
    tile_size = args['tilesize']
    img_size = args['imgsize']
    pix_size_deg = args['pixsize']

    metafits_file = f"{GLOBAL_CONFIG["data_path_prefix"]}/{args["obsid"]}/{args["obsid"]}.metafits"
    pc_ra_deg, pc_dec_deg, flagged_antennas = get_info_from_metafits(metafits_file)
    
    if args['no_flags']:
        flagged_antennas = []

    submit_job(args["obsid"], args['calid'], args["imgsize"], None, None, not args["mwax"],
        args["offset"], args["duration"], flagged_antennas, args["partition"], args["account"], args["time"])