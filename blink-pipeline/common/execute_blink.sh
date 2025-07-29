#!/bin/bash

# A set of functions that help processing VCS datasets using blink

function print_run {
	echo "Executing $@"
	$@
}


function run_blink {

    if [ -z ${OBSERVATION_ID+x} ]; then
        echo "OBSERVATION_ID not set."
        exit 1
    fi
    
    if [ -z ${SOLUTION_ID+x} ]; then
        echo "SOLUTION_ID not set."
        exit 1
    fi

    if [ -z ${TIME_RESOLUTION+x} ]; then
        TIME_RESOLUTION="20ms"
    fi
    
    if [ -z ${CHANNEL_AVG+x} ]; then
        CHANNEL_AVG=4
    fi

    if [ -z ${IMG_SIZE+x} ] ; then
        IMG_SIZE=1024
    fi        
    if [ -z ${SLM_ACCOUNT+x} ]; then
        SLM_ACCOUNT=pawsey1154-gpu
    fi
    
    if [ -z ${SNR+x} ]; then
        SNR=4.5
    fi
    
    if [ -z ${ 
    INPUT_DIR=/scratch/${PAWSEY_PROJECT}/${USER}/${OBSERVATION_ID}
    METAFITS=${INPUT_DIR}/${OBSERVATION_ID}.metafits
    SOL_FILE=${INPUT_DIR}/${SOLUTION_ID}.bin
    VOLTAGE_DIR=${INPUT_DIR}/combined
    OUTPUT_DIR=$MYSCRATCH/${OBSERVATION_ID}_output${OUTPUT_SUFFIX}
    
    if ! [ -e $OUTPUT_DIR ]; then
      mkdir -p $OUTPUT_DIR
      # tells Lustre FS to only use the Flash pool (SSDs)
      # lfs setstripe -p flash $OUTPUT_DIR
    fi

    filelist=(`ls -1 ${VOLTAGE_DIR}/*.dat`)
    if ! [ -z ${SECONDS_TO_PROCESS} ]; then
        # we only want to process the first N seconds, likely for testing
        n_files_to_process=$((SECONDS_TO_PROCESS * 24))
        INPUT_FILES=${filelist[@]:0:n_files_to_process} 
        BLINK_COMMAND_LINE="`which blink_pipeline` -c $CHANNEL_AVG -t ${TIME_RESOLUTION} -o ${OUTPUT_DIR}${OUTPUT_SUFFIX} -n ${IMG_SIZE}  -M ${METAFITS} -r -s ${SOL_FILE} -b 0 -S 4.5 -D55:60:1 $INPUT_FILES"
         
    else
        # we want to process the entire observation
        seconds_per_run=100
        n_files=${#filelist[@]}
        processed=0
        count=0
        while (( processed < n_files )); 
        do
        n_files_to_process=$((seconds_per_run * 24))
        INPUT_FILES=${filelist[@]:processed:n_files_to_process}
        BLINK_COMMAND_LINE="`which blink_pipeline` -c $CHANNEL_AVG -t ${TIME_RESOLUTION} -o ${OUTPUT_DIR}_newpart${count} -n 1000 -M ${METAFITS} -r -s ${SOL_FILE} -b 0 -S 4.5 -D55:60:1 $INPUT_FILES"
        #sbatch --account=mwavcs-gpu --gres=gpu:8 --partition=mwa-gpu --time=24:00:00 --export=ALL  --wrap "srun -c 64 -n1 ${BLINK_COMMAND_LINE}"
        sbatch --account=pawsey1154-gpu --gres=gpu:8 --partition=gpu --time=04:00:00 --export=ALL  --wrap "srun -c 64 -n1 ${BLINK_COMMAND_LINE}"
        processed=$((processed + n_files_to_process))
        count=$((count + 1))
        done
    fi
}


run_blink_command $@
