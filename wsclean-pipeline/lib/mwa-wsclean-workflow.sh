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
if [ -z ${PAWSEY_CLUSTER+x} ]; then
LAUNCHER="srun"
fi

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
    print_run cp "${original_metadata}" "${new_metadata}"
    print_run python3 "${SCRIPT_DIR}/fix_metafits_time_radec.py" "${new_metadata}"
}


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
    for input_file in `ls -1 ${INPUT_DATA_FILES} | sort`; do
    START_SECOND=${OBS_UNIX_TIMESTAMP}
    DUMPS_PER_SECOND=1
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
    echo "Offline correlator ended at" `date +"%s"`
    
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

    print_run ${LAUNCHER} cotter  -j ${NCORES}  -timeres 1 -freqres 0.04 -edgewidth 80 -noflagautos -norfi -nostats -full-apply ${bin_file} -flagantenna 25,58,71,80,81,92,101,108,114,119,125 -m "${METADATA_DIR}/${UTC_TIMESTAMP}.metafits" -noflagmissings -allowmissing -offline-gpubox-format -initflag 0  -centre 18h33m41.89s -03d39m04.25s -o corrected_visibilities.ms ${RAW_VISIBILITIES}

    echo "Cotter ended at" `date +"%s"`
    cd -
}

function run_wsclean {
    img_dir="${CURRENT_SECOND_WORK_DIR}/images"
    imagesize=1024
    weighting=briggs
    pixscale=0.08
    n_iter=0
    output_image_name="${OBSERVATION_ID}_${OBS_GPSTIME}_${imagesize}_${weighting}"
    if [ -e ${img_dir}/${output_image_name}*dirty.fits ]; then
        echo "Skipping run_wsclean... images already exist."
        return 0
    fi
    mkdir -p "${img_dir}"
    cd "${img_dir}"
    #  -use-idg -idg-mode gpu
    print_run ${LAUNCHER} wsclean -name ${output_image_name} -j ${NCORES} -size ${imagesize} ${imagesize}  -pol i  -absmem 64 -weight ${weighting} 0 -scale $pixscale -niter ${n_iter} "${CURRENT_SECOND_WORK_DIR}/corrected_visibilities.ms"
}

