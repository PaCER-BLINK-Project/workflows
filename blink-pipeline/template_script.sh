#!/bin/bash -e 
#SBATCH --account=pawsey1154-gpu
#SBATCH --gres=gpu:8
#SBATCH --partition=gpu
#SBATCH --time=24:00:00
#SBATCH --export=NONE
#SBATCH --output=slurm-%A.out 
# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}
module load blink-pipeline-gpu/main

OBSERVATION_ID=1192477696
SOLUTION_ID=1192467680

DM_START=$1
DM_END=$((DM_START + 10))

INPUT_DIR=/scratch/pawsey1154/cdipietrantonio/1192477696 
INPUT_FILES="${INPUT_DIR}/combined" 
METAFITS=$INPUT_DIR/$OBSERVATION_ID.metafits
SOL_FILE=/scratch/pawsey1154/cdipietrantonio/${OBSERVATION_ID}/1192467680.bin

OUTPUT_DIR=$MYSCRATCH/${OBSERVATION_ID}_highdm
if ! [ -e $OUTPUT_DIR ]; then
  mkdir -p $OUTPUT_DIR
  # tells Lustre FS to only use the Flash pool (SSDs)
  # lfs setstripe -p flash $OUTPUT_DIR
fi
# export HSA_XNACK=1
# export AMD_LOG_LEVEL=3
srun  --export=ALL -u --gres=gpu:8  -n1  `which blink_pipeline` -c 4 -t 20ms -o ${OUTPUT_DIR} -n 1024  -M ${METAFITS} -r -s ${SOL_FILE} -b 0 -I  ${INPUT_FILES} -D ${DM_START}:${DM_END}:1 -S10 -f8 -p dm_${DM_START}_${DM_END} -Q 600

