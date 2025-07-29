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

    INPUT_DIR=/scratch/${PAWSEY_PROJECT}/${USER}/${OBSERVATION_ID}
    METAFITS=${INPUT_DIR}/${OBSERVATION_ID}.metafits
    SOL_FILE=${INPUT_DIR}/${SOLUTION_ID}.bin
    VOLTAGE_DIR=${INPUT_DIR}/combined
    OUTPUT_DIR=$MYSCRATCH/${OBSERVATION_ID}_output
    
    #if ! [ -e $OUTPUT_DIR ]; then
    #  mkdir -p $OUTPUT_DIR
    #  # tells Lustre FS to only use the Flash pool (SSDs)
    #  # lfs setstripe -p flash $OUTPUT_DIR
    #fi

    filelist=(`ls -1 ${VOLTAGE_DIR}/*.dat`)
    if ! [ -z ${SECONDS_TO_PROCESS} ]; then
        # we only want to process the first N seconds, likely for testing
        n_files_to_process=$((SECONDS_TO_PROCESS * 24))
        INPUT_FILES=${filelist[@]:0:n_files_to_process} 
        $DEBUG_LINE `which blink_pipeline` $@  -o ${OUTPUT_DIR}${OUTPUT_SUFFIX} -M ${METAFITS} -r -s ${SOL_FILE} -b 0 $INPUT_FILES
         
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
        if ! [ "${IMAGING}" = "1" ]; then 
            FINAL_OUTPUT_DIR="${OUTPUT_DIR}${OUTPUT_SUFFIX}_part${count}"
        else 
            FINAL_OUTPUT_DIR="${OUTPUT_DIR}${OUTPUT_SUFFIX}"
         fi
        BLINK_COMMAND_LINE="`which blink_pipeline` $@  -o ${FINAL_OUTPUT_DIR} -M ${METAFITS} -r -s ${SOL_FILE} -b 0 $INPUT_FILES"
        if [ ${IMAGING} = "1" ]; then
        sbatch --account=pawsey1154-gpu --gres=gpu:3 --partition=gpu --time=04:00:00 --export=ALL --wrap "srun -c24 -n1 --gres=gpu:1 ${BLINK_COMMAND_LINE}"
        else
        sbatch --account=pawsey1154-gpu --gres=gpu:8 --partition=gpu --time=04:00:00 --export=ALL --wrap "srun -c64 -n1 ${BLINK_COMMAND_LINE}"
        fi
        processed=$((processed + n_files_to_process))
        count=$((count + 1))
        done
    fi
}
