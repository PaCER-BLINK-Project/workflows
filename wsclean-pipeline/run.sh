#!/bin/bash
module use /pawsey/mwa/software/python3/modulefiles
module use /scratch/director2183/cdipietrantonio/garrawarla/cotter/install/modulefiles
module load cfitsio/4.3.1 cuda/11.4.2 cmake/3.24.3

module load offline_correlator/v1.0.0
module load wsclean/2.9
module load cotter/devel
module load python/3.8.2 astropy


OBSERVATIONS_ROOT_DIR=/scratch/mwavcs/msok/1276619416/combined #/group/director2183/cdipietrantonio/obs-data
OBSERVATION_ID=1276619416
OBS_GPSTIME=1276619418
WORK_DIR=${MYSCRATCH}/test-old-pipeline


CURRENT_SECOND_WORK_DIR="${WORK_DIR}/${OBSERVATION_ID}/${OBS_GPSTIME}"
OBS_UNIX_TIMESTAMP=$((315964800 + ${OBS_GPSTIME} - 18))
UTC_TIMESTAMP=`date -u +'%Y%m%d%H%M%S' -d@${OBS_UNIX_TIMESTAMP}`
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
METADATA_DIR="${WORK_DIR}/${OBSERVATION_ID}/metadata"
CALIBRATION_DIR="${WORK_DIR}/${OBSERVATION_ID}/calibration_data"


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
    echo "N_FITS = $N_FITS"
    if [ $N_FITS -eq 24 ]; then
        echo "Skipping correlation... raw visibilities already exist."
        return 0
    fi
    INPUT_DATA_FILES=${OBSERVATIONS_ROOT_DIR}/${OBSERVATION_ID}_${OBS_GPSTIME}_*
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
    srun  offline_correlator\
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

    print_run cotter  -j 40 -timeres 1 -freqres 0.04 -edgewidth 80 -noflagautos -norfi -nostats -full-apply ${bin_file} -flagantenna 25,58,71,80,81,92,101,108,114,119,125 -m "${METADATA_DIR}/${UTC_TIMESTAMP}.metafits" -noflagmissings -allowmissing -offline-gpubox-format -initflag 0  -centre 18h33m41.89s -03d39m04.25s -o corrected_visibilities.ms ${RAW_VISIBILITIES} 

    echo "Cotter ended at" `date +"%s"`
    cd -
}

function run_wsclean {
    img_dir="${CURRENT_SECOND_WORK_DIR}/images"
    mkdir -p "${img_dir}"
    cd "${img_dir}"
    # Run wsclean
    imagesize=1024
    weighting=briggs
    pixscale=0.08
    n_iter=0
    #  -use-idg -idg-mode gpu
    print_run wsclean -name ${OBSERVATION_ID}_${OBS_GPSTIME}_${imagesize}_${weighting}  -j 6 -size ${imagesize} ${imagesize}  -pol i  -absmem 64 -weight ${weighting} 0 -scale $pixscale -niter ${n_iter} "${CURRENT_SECOND_WORK_DIR}/corrected_visibilities.ms" 
}

# =========================================================================================
#                                        MAIN SCRIPT
# =========================================================================================


download_metadata
download_calibration_data
fix_metadata 
run_correlator
run_cotter
run_wsclean

