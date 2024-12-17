#!/bin/bash

# Calling script needs to define the following variables 
# - OBSERVATIONS_ROOT_DIR: path to the directory cotaining combined dat files, eg. #/scratch/mwavcs/msok/1276619416/combined
# - WORK_DIR: top level working directory where output files are written, eg. ${MYSCRATCH}/test-old-pipeline

SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

# Determining the number of CPU cores that can be used
N_CPU_SOCKETS=`cat /proc/cpuinfo | grep "physical id"  | sort | uniq | wc -l`
N_CORES_PER_SOCKET=`cat /proc/cpuinfo | grep "cpu cores" | head -n1 | grep -oE [0-9]+`
NCORES=$(( N_CPU_SOCKETS * N_CORES_PER_SOCKET ))

LAUNCHER=""
if ! [ -z ${PAWSEY_CLUSTER+x} ]; then
echo "Using Pawsey cluster ${PAWSEY_CLUSTER}"
LAUNCHER="srun -c $SLURM_CPUS_PER_TASK"
fi

PERF="perf record -g --call-graph dwarf -F 9000"

# set_observation
# Description: set the observation ID and the GPS second to process.
# Params:
# - $1: Observation ID
# - $2: GPS second
function set_observation {
    OBSERVATION_ID="$1"
    OBS_GPSTIME="$2"
    CURRENT_SECOND_WORK_DIR="${WORK_DIR}/${OBSERVATION_ID}/${OBS_GPSTIME}"
    OBS_UNIX_TIMESTAMP=$((315964800 + ${OBS_GPSTIME} - 18))
    UTC_TIMESTAMP=`date -u +'%Y%m%d%H%M%S' -d@${OBS_UNIX_TIMESTAMP}`
    METADATA_DIR="${WORK_DIR}/${OBSERVATION_ID}/metadata"
    CALIBRATION_DIR="${WORK_DIR}/${OBSERVATION_ID}/calibration_data"
}

function set_time_resolution {
    resolution="$1"
    if [ "$resolution" = "1s" ]; then
        DUMPS_PER_SECOND=1
        COTTER_TIMERES=1
    elif [ "$resolution" = "50ms" ]; then
        DUMPS_PER_SECOND=20
        COTTER_TIMERES=0.05
    else
        echo "run_correlator error: expected a time resolution as parameter."
        exit 1
    fi
}

function print_run {
 echo "$@"
 $@
}


function download_metadata {
    mkdir -p "${METADATA_DIR}" 
    metadata_file="${METADATA_DIR}/${OBSERVATION_ID}.metafits"
    if [ -e ${metadata_file} ]; then
        echo "Skipping downloading metadata... file already exists."
        return 0
    fi
    url="http://ws.mwatelescope.org/metadata/fits?obs_id="
    print_run wget ${url}${OBSERVATION_ID} -O ${metadata_file} 
}

function download_calibration_data {
    mkdir -p "${CALIBRATION_DIR}"
    [ -e "${CALIBRATION_DIR}/solutions.zip" ] || \
        print_run wget "http://ws.mwatelescope.org/calib/get_calfile_for_obsid?obs_id=${OBSERVATION_ID}&zipfile=1&add_request=1" -O "${CALIBRATION_DIR}/solutions.zip"
    cd "${CALIBRATION_DIR}"
    [ -e *.bin ] || print_run unzip solutions.zip
    cd - 
}

function fix_metadata {
    original_metadata="${METADATA_DIR}/${OBSERVATION_ID}.metafits"
    new_metadata="${METADATA_DIR}/${UTC_TIMESTAMP}.metafits"
    if [ -e "${new_metadata}" ]; then
        echo "Skipping fix_metadata... new metadata file already exists."
        return 0
    fi
    print_run python3 "${SCRIPT_DIR}/fix_metafits_time_radec.py" -t ${DUMPS_PER_SECOND} -c 768 -i ${COTTER_TIMERES} -g ${OBS_GPSTIME} -o ${METADATA_DIR} "${original_metadata}"
}

# run_correlator <timeres>
function run_correlator {
    vis_dir="${CURRENT_SECOND_WORK_DIR}/raw_visibilities"
    [ -d ${vis_dir} ] || mkdir -p ${vis_dir} 
    cd ${vis_dir}
    N_FITS=`ls -1 | grep -e fits | wc -l`
    if [ $N_FITS -eq 24 ]; then
        echo "Skipping correlation... raw visibilities already exist."
        return 0
    fi
    INPUT_DATA_FILES="${OBSERVATIONS_ROOT_DIR}/${OBSERVATION_ID}_${OBS_GPSTIME}_*.dat"
    # This will only work for coarse channels >= 133
    inverse_gpu_boxes=("24" "23" "22" "21" "20" "19" "18" "17" "16" "15" "14" "13" "12" "11" "10" "09" "08" "07" "06" "05" "04" "03" "02" "01")
    declare -i index
    index=0
    echo "Offline correlator started at" `date +"%s"`
    p_start_time=`date +%s`
    for input_file in `ls -1 ${INPUT_DATA_FILES} | sort`; do
    START_SECOND=${OBS_UNIX_TIMESTAMP}
    CHANS_TO_AVERAGE=4
    GPUBOX_CHANNEL_NUMBER=${inverse_gpu_boxes[$index]}
    OUTPUT_PREFIX=$OBSERVATION_ID
    export obsid=${OBSERVATION_ID} 
    print_run ${LAUNCHER} offline_correlator\
       -d $input_file\
       -s $START_SECOND\
       -r $DUMPS_PER_SECOND\
       -n $CHANS_TO_AVERAGE\
       -c $GPUBOX_CHANNEL_NUMBER\
       -o $OUTPUT_PREFIX > /dev/null
    
    (( index=index + 1 ))
    done
    p_end_time=`date +%s`
    p_elapsed=$((p_end_time-p_start_time))
    echo "Offline correlator took $p_elapsed seconds."
    cd - 
}

function run_cotter {
    if [ -e "${CURRENT_SECOND_WORK_DIR}/corrected_visibilities.ms" ]; then
        echo "Skipping cotter because corrected visibilities already exist."
        return 0
    fi
    cd "$CURRENT_SECOND_WORK_DIR/"
    # Offline correlator vis
    RAW_VISIBILITIES="${CURRENT_SECOND_WORK_DIR}/raw_visibilities/*.fits"
    bin_file=`ls ${CALIBRATION_DIR}/*.bin`
    
    # Run contter
    object="00h36m08.95s -10d34m00.3s"
    echo "Cotter started at" `date +"%s"`
    p_start_time=`date +%s`
     # -centre 18h33m41.89s -03d39m04.25 -edgewidth=80
    print_run ${LAUNCHER} cotter  -j ${NCORES}  -timeres ${COTTER_TIMERES} -freqres 0.04 -edgewidth 0 -noflagautos -norfi -nostats -full-apply ${bin_file} -flagantenna 25,58,71,80,81,92,101,108,114,119,125 -m "${METADATA_DIR}/${UTC_TIMESTAMP}.metafits" -noflagmissings -allowmissing -offline-gpubox-format -initflag 0   -o corrected_visibilities.ms ${RAW_VISIBILITIES}
    p_end_time=`date +%s`
    p_elapsed=$((p_end_time-p_start_time))
    echo "Cotter took $p_elapsed seconds."
    cd -
}

function run_birli {
    if [ -e "${CURRENT_SECOND_WORK_DIR}/corrected_visibilities.ms" ]; then
        echo "Skipping cotter because corrected visibilities already exist."
        return 0
    fi
    cd "$CURRENT_SECOND_WORK_DIR/"
    # Offline correlator vis
    RAW_VISIBILITIES="${CURRENT_SECOND_WORK_DIR}/raw_visibilities/*.fits"
    bin_file=`ls ${CALIBRATION_DIR}/*.bin`
    # Run contter
    object="00h36m08.95s -10d34m00.3s"
    p_start_time=`date +%s`
    echo "Birli started at" `date +"%s"`
    # --phase-centre 18h33m41.89s -03d39m04.25s
    print_run ${LAUNCHER} birli --avg-time-res ${COTTER_TIMERES} --avg-freq-res 0.04  --flag-edge-width 0  --no-rfi --apply-di-cal  ${bin_file} --flag-antennas 25,58,71,80,81,92,101,108,114,119,125 -m "${METADATA_DIR}/${UTC_TIMESTAMP}.metafits"  --flag-init 0   --ms-out corrected_visibilities.ms ${RAW_VISIBILITIES}
    p_end_time=`date +%s`
    p_elapsed=$((p_end_time-p_start_time))
    echo "Birli took $p_elapsed seconds."
    cd -
}

# run_wsclean <image_size> <pix_scale> <weighting>
function run_wsclean {
    img_dir="${CURRENT_SECOND_WORK_DIR}/images"
    imagesize="$1"
    weighting="$3"
    pixscale="$2"
    n_iter=0
    channels_out="" #"-channels-out 768"
    iout=1 #${DUMPS_PER_SECOND}
    gridder="idg -idg-mode gpu"
    # gridder="wgridder"
    output_image_name="${OBSERVATION_ID}_${OBS_GPSTIME}_${imagesize}_${pixscale}_idg"
    if [ -e ${img_dir}/${output_image_name}*dirty.fits ]; then
        echo "Skipping run_wsclean... images already exist."
        return 0
    fi
    mkdir -p "${img_dir}"
    cd "${img_dir}"
    p_start_time=`date +%s`
    print_run ${LAUNCHER} wsclean -name ${output_image_name} -j ${NCORES} -size ${imagesize} ${imagesize}  -pol i -intervals-out ${iout} -use-idg -idg-mode gpu   -weight ${weighting} -nwlayers 1 -scale $pixscale -niter ${n_iter} ${channels_out} "${CURRENT_SECOND_WORK_DIR}/corrected_visibilities.ms" 
    # print_run ${LAUNCHER} wsclean -name ${output_image_name} -j ${NCORES} -size ${imagesize} ${imagesize}  -pol i -intervals-out ${iout} -gridder wgridder  -weight ${weighting} -scale $pixscale -niter ${n_iter} ${channels_out} "${CURRENT_SECOND_WORK_DIR}/corrected_visibilities.ms" 
    p_end_time=`date +%s`
    p_elapsed=$((p_end_time-p_start_time))
    echo "WSClean took $p_elapsed seconds."
}

