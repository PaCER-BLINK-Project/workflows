#!/usr/bin/env python3
from astropy.io import fits
import argparse
from itertools import product
import os
from math import sqrt

# Script to tile an observation's FoV in smaller chunks
# for processing with the BLINK pipeline.
# The following is the maximum baseline length allowed in the MWAX SMART observations.
MAX_BASELINE_LENGTH = 524.1177408273832

# The following array was needed to manually flag antennas that contributed to long baselines.
# Now these are automatically identified given the metafits file with the antenna information,
# and a maximum baseline length. See the `Graph` class below for more info.
SMART_ANTENNAS_OUTSIDE_CORE = [
    "LBF1",
    "LBF2",
    "LBF3",
    "LBF4",
    "LBF5",
    "LBF6",
    "LBF7",
    "LBF8",
    "LBG1",
    "LBG2",
    "LBG3",
    "LBG4",
    "LBG5",
    "LBG6",
    "LBG7",
    "LBG8",
    "Tile091",
    # "Tile088",
    # "Tile098",
    # "Tile097",
    "Tile087",
    # "Tile081",
#    "Tile092",
#    "Tile082",
#    "Tile028",
]

GLOBAL_CONFIG = {
    "data_path_prefix" : f"/scratch/pawsey1154/{os.getenv('USER')}",
    "project_modulepath" : " /software/projects/pawsey1154/setonix/2025.08/modules/zen3/gcc/14.2.0",
    "user_modulepath" : f"/software/projects/pawsey1154/{os.getenv('USER')}/setonix/2025.08/modules/zen3/gcc/14.2.0"
}

SEARCH_PARAMETERS = {
 
    # NOTE: This could actually be the search configuration for all the observations, after
    # if the maximum baseline length is set to be the SMART one.
    'SMART' : {
        'oversampling' : 1,
        'imgsize' : 256,
        'dm_range' : [
            '10:100:1',
            '101:200:1',
            '201:300:1',
            '301:400:1',
            '401:500:1',
            '501:550:1',
            '551:600:1'
        ],
        'dmrange_to_timelimit' : {
            '10:100:1' : '12:00:00',
            '101:200:1' : '14:00:00',
            '201:300:1' : '17:00:00',
            '301:400:1' : '19:00:00',
            '401:500:1' : '22:00:00',
            '501:550:1' : '13:00:00',
            '551:600:1': '13:00:00'
        },
        # number of seconds to process for each job
        'duration' : 600,
        # start points within the observation
        # now automatically computed
        # 'offsets' : [0, 1170, 2340, 3510, 4680], # allow 30 seconds overlap
    }
}



class Graph:
    """
    The following method identifies the minimal set of stations to be flagged such that
    all the long baselines are removed, long being an arbitrary threshold.

    1. Build a graph where each node is a station and there is an edge between two nodes
    if those nodes represent a long baseline.

    2. Sort nodes by number of edges.

    3. Iteratively flag the node/station with highest number of edges, until there are no edges 
    left in the graph between unflagged nodes.

    However, it would be better to flag baselines in the imager. This is just a workaround.

    """
    def __init__(self):
        self.data = {}
    
    def add_edge(self, x, y):
        s1 : set = self.data.setdefault(x, set())
        s1.add(y)
        s2 : set = self.data.setdefault(y, set())
        s2.add(x)


    def reemove_largest_node(self):
        vals = [(x, len(self.data[x])) for x in self.data]
        max_node = max(vals, key= lambda x : x[1])
        neighbours = self.data[max_node[0]]
        del self.data[max_node[0]]
        for n in neighbours:
            self.data[n].remove(max_node[0])
        return max_node


def find_faraway_tiles(metafits_file, max_distance):
    """
    Find all the tiles that make the baseline distance above the maximum allowed.
    """
    hdus = fits.open(metafits_file)
    antenna_pos = []
    for row in hdus[1].data:
        antenna_pos.append((row['Tilename'], row['East'], row['North'], row['Height']))
    
    n_ant = len(antenna_pos)

    def comp_dist(a, b):
        return sqrt((a[1] - b[1])**2 +  (a[2] - b[2])**2 +  (a[3] - b[3])**2)

    G = Graph()

    for i in range(n_ant):
        for j in range(0, i):
            dist = comp_dist(antenna_pos[i], antenna_pos[j])
            if dist > max_distance:
                G.add_edge(antenna_pos[i][0], antenna_pos[j][0])
    
    flagged_tiles = []
    while True:
        node_id, neigh_count = G.reemove_largest_node()
        if neigh_count == 0: break
        flagged_tiles.append(node_id)

    return flagged_tiles



def print_baseline_lengths(metafits_file):
    """
    Helper function just used for testing. Used to print list of baselines and associated length.
    """
    hdus = fits.open(metafits_file)
    ra = hdus[0].header['RA']
    dec = hdus[0].header['DEC']
    antenna_pos = []
    for row in hdus[1].data:
        if row['Tilename'] in SMART_ANTENNAS_OUTSIDE_CORE: continue
        antenna_pos.append((row['Antenna'], row['East'], row['North'], row['Height']))
    
    n_ant = len(antenna_pos)
    baseline_lengths = []
    from math import sqrt

    def comp_dist(a, b):
        return sqrt((a[1] - b[1])**2 +  (a[2] - b[2])**2 +  (a[3] - b[3])**2)

    for i in range(n_ant):
        for j in range(0, i):
            baseline_lengths.append((antenna_pos[i][0], antenna_pos[j][0], comp_dist(antenna_pos[i], antenna_pos[j])))
    
    sorted_lengths = sorted(baseline_lengths, key=lambda x: x[2])
    for i, v in enumerate(sorted_lengths):
        print(v)



def get_info_from_metafits(metafits_file, skip_long_baselines = True, maximum_baseline_length = MAX_BASELINE_LENGTH):
    hdus = fits.open(metafits_file)
    ra = hdus[0].header['RA']
    dec = hdus[0].header['DEC']

    # now get the antennas that were already flagged
    flagged_antennas = set([row['ANTENNA'] for row in hdus[1].data if row['FLAG'] > 0])
    if skip_long_baselines:
        # must flag antennas that contribute to generate long baselines.
        # This is a workaround, we should flag baselines in the gridding code in the imager.
        if True: # Old method: exclude hardcoded tiles - which works but tedious.
            outside_core = set()
            for row in hdus[1].data:
                if row['TILENAME'] in SMART_ANTENNAS_OUTSIDE_CORE:
                    outside_core.add(row['ANTENNA'])
        else:
            # This is not working properly yet ...
            outside_core = set(find_faraway_tiles(metafits_file, maximum_baseline_length))
        flagged_antennas = flagged_antennas.union(outside_core)
    n_antennas = len(hdus[1].data) // 2
    project = hdus[0].header['PROJECT']
    mode = hdus[0].header['MODE']
    return project, mode, ra, dec, n_antennas, flagged_antennas


# TODO set proper output log directory / policy
# TODO print job cost prediction

def submit_job(observation_id : int, n_antennas : int, image_size : int,
        ra : float, dec : float, reorder : bool, start_offset : int,
        duration : int, time_res : float, freq_avg_factor : int,
        oversampling : float, average_images : bool, flagging_threshold : float,
        flagged_antennas : list, dedisp : str, snr : float, dyspec : str,
        slm_partition : str, slm_account : str, slm_time : str,
        dir_postfix : str, file_postfix : str, module : str, dry_run : bool, nice : bool):

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
    output_dir = f"{observation_path}_output" #_output_ra{ra:.3f}_dec{dec:.3f}"
    if dir_postfix is not None: output_dir += f"_{dir_postfix}"
    slurm_out_file = f"{output_dir}/slurm-%A.out"
    
    if dedisp is not None:
        job_title = f"BLINK Dedispersion - {observation_id} - OFFSET {start_offset} - DM range {dedisp}"
    elif dyspec is not None:
        job_title = f"BLINK Dynamic Spectrum - {observation_id} - {dyspec}"
    else:
        job_title = f"BLINK Imaging - {observation_id}"
    
    slurm_sbatch_args = f"--gres=gpu:8 --partition={slm_partition} --job-name=\"{job_title}\" " \
        f"--account={slm_account}-gpu --output={slurm_out_file} --time={slm_time} --no-requeue "
    
    if nice or slm_partition == "mwa-gpu":
        slurm_sbatch_args += "--nice=1500"

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
        postfix = f"start_second_{start_offset}_dm_range_{dedisp.replace(':', '_')}"
        blink_line += f' -D {dedisp} -S {snr} -p {postfix} '

    if dyspec is not None:
        if dedisp is None and file_postfix is not None:
            blink_line += f" -p {file_postfix} "
        blink_line += f' -d {dyspec} '
    
    module_env_setup = f"""
    module use {GLOBAL_CONFIG["project_modulepath"]};
    module use {GLOBAL_CONFIG["user_modulepath"]};
    module load {module};
    """
    
    wrap_command  = module_env_setup
    wrap_command += f"{blink_line} ;"

    if dyspec is not None:
        if dedisp is not None:
            wrap_command += f"cd {output_dir}; ls -1 dynamic_spectrum_*{postfix}.fits > fits_list_{postfix}; test_totalpower fits_list_{postfix};"
            wrap_command += f"mv dynamic_spectrum_*{postfix}.total_power totalpower_{start_offset}.power ;"
    
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
    parser.add_argument("--snr", type=float, default=7, help="SNR threshold for detections in dedispersion mode.")
    parser.add_argument("--time-res", type=float, default=0.02, help="Time resolution.")
    parser.add_argument("--freq-avg", type=int, default=4, help="Frequency averaging factor.")
    parser.add_argument("--oversampling", type=float, default=2, help="Imaging oversampling factor.")
    parser.add_argument("--avg-images", action='store_true', help="Enable image averaging across the entire coarse channel and second.")
    parser.add_argument("--img-flag", type=float, default=5, help="Image RMS flagging threshold.")

    # execution modes
    parser.add_argument("--dyspec", type=str, default=None, help="Enable dynamic spectrum mode by passing pixels coordinates (x1,y1:x2,y2:x3,y3).")
    parser.add_argument("--dedisp", type=str, default=None, help="Enable dedispersion mode by passing the DM range in the format min:max:step (e.g. 50:60:1)")
    parser.add_argument("--dry-run", action='store_true', help="Do not actually submit jobs.")
    parser.add_argument("--dir-postfix", type=str, default=None, help="Adds the specified postfix to the output directory.")
    parser.add_argument("--file-postfix", type=str, default=None, help="Adds the specified postfix to the output files.")
    parser.add_argument("--search", action='store_true', help="Run an FRB search over the entire parameter space.")
    parser.add_argument("--time-bins", type=int, default=[], nargs='*', help="Limit the search to the specified time intevals. Intervals are specified with 0-based indexing.")
    parser.add_argument("--dm-bins", type=int,default=[],  nargs='*', help="Limit the search to the specified DM intevals. Intervals are specified with 0-based indexing.")
    parser.add_argument("--module", type=str, default="blink-pipeline-gpu/main", help="LMOD module to load the BLINK-pipeline.")
    parser.add_argument("--int-offset", type=int, default=0, help="Skip the specified number of initial seconds within a time bin. " \
                        "Useful for check-pointing, when a job goes in time out. For instance, an internal offset of 500 in the time bin 1 " \
                        "Will start the processing at second 570 + 500 = 1070, and also shorten the duration of the same amount.")
    parser.add_argument("--long", action='store_true', help="DO NOT discard longer baselines.")
    # SLURM configuratino options
    parser.add_argument("--partition", default="gpu", type=str, help="Setonix GPU partition where to submit the job")
    parser.add_argument("--account", default="pawsey1154", type=str, help="Setonix account billed for the job.")
    parser.add_argument("--time", type=str, default="24:00:00", help="Slurm job walltime.")
    parser.add_argument("--nice", action='store_true', help="Pass the --nice option to SLURM to artificially lower the priority.")

    args = vars(parser.parse_args())
    
    metafits_file = f"{GLOBAL_CONFIG['data_path_prefix']}/{args['obsid']}/{args['obsid']}.metafits"
    project, mode, pc_ra_deg, pc_dec_deg, n_antennas, flagged_antennas = get_info_from_metafits(metafits_file, not args['long'])
    farway_tiles = find_faraway_tiles(metafits_file, MAX_BASELINE_LENGTH)
    
    reorder = not mode == 'MWAX_VCS' 

    if args['no_flags']:
        flagged_antennas = []
    
    if args['centre'] is not None:
        tokens = args['centre'].split(',')
        if len(tokens) != 2: raise ValueError("Phase centre spec is malformed.")
        pc_ra_deg, pc_dec_deg = float(tokens[0]), float(tokens[1])
    

    if args['search']:
        observation_path = f"{GLOBAL_CONFIG['data_path_prefix']}/{args['obsid']}"
        combined_files_path = f"{observation_path}/combined"

        dat_files = [x for x in os.listdir(combined_files_path) if x.endswith(".dat")]
        n_seconds = len(dat_files) // 24
        print("The observation's number of seconds is", n_seconds)
        duration = SEARCH_PARAMETERS['SMART']['duration']
        offsets = []
        # TODO: compute overlap by DM
        overlap = 30
        i = 0
        while i < n_seconds:
            offsets.append(i)
            i += duration - overlap
        
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
                curr_duration = -1 if (i == len(offsets) - 1) else duration
                ioff = args["int_offset"]
                curr_duration -= ioff
                offset += ioff
                img_size = SEARCH_PARAMETERS['SMART']['imgsize']
                time_limit = SEARCH_PARAMETERS['SMART']['dmrange_to_timelimit'][dm_range]
                submit_job(args["obsid"], n_antennas, img_size, pc_ra_deg, pc_dec_deg, 
                    reorder,
                    offset, curr_duration, args["time_res"], args["freq_avg"], SEARCH_PARAMETERS['SMART']['oversampling'],
                    args["avg_images"], args["img_flag"], flagged_antennas, dm_range,
                    args["snr"], f"{img_size//2},{img_size//2}", args["partition"], args["account"], time_limit,
                    args["dir_postfix"], args["file_postfix"], args["module"], args["dry_run"], args["nice"])
        
        # TODO: add estimate of cost in SU in printed summary
    else:

        submit_job(args["obsid"], n_antennas, args["imgsize"], pc_ra_deg, pc_dec_deg, reorder,
            args["offset"], args["duration"], args["time_res"], args["freq_avg"], args["oversampling"],
            args["avg_images"], args["img_flag"], flagged_antennas, args["dedisp"],
            args["snr"], args["dyspec"], args["partition"], args["account"], args["time"],
            args["dir_postfix"], args["file_postfix"], args["module"], args["dry_run"], args["nice"])
