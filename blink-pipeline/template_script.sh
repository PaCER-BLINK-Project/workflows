#!/bin/bash -e 
#SBATCH --account=pawsey1154-gpu
#SBATCH --gres=gpu:8
#SBATCH --partition=gpu
#SBATCH --time=24:00:00
#SBATCH --export=NONE
#SBATCH --output=slurm-%A.out 


module load blink-pipeline-gpu/main

OBSERVATION_ID=1192477696
SOLUTION_ID=1192467680

INPUT_DIR="/scratch/${PAWSEY_PROJECT}/${USER}/${OBSERVATION_ID}"
INPUT_FILES="${INPUT_DIR}/combined"
METAFITS="${INPUT_DIR}/${OBSERVATION_ID}.metafits"
SOL_FILE="${INPUT_DIR}/1192467680.bin"

OUTPUT_DIR=$MYSCRATCH/${OBSERVATION_ID}_output

if ! [ -e $OUTPUT_DIR ]; then
  mkdir -p $OUTPUT_DIR
  # tells Lustre FS to only use the Flash pool (SSDs)
  # lfs setstripe -p flash $OUTPUT_DIR
fi

srun  --export=ALL -u --gres=gpu:8  -n1  `which blink_pipeline` -c 4 -t 20ms -o ${OUTPUT_DIR} -n 1024  -M ${METAFITS} -r -s ${SOL_FILE} -b 0 -I  ${INPUT_FILES} -D 50:60:1 -S10 -f8 -Q 600

