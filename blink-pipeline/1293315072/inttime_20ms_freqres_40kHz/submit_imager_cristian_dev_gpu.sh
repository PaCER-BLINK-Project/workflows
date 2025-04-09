#!/bin/bash -e 
#SBATCH --account=pawsey1154-gpu
#SBATCH --gres=gpu:3
#SBATCH --partition=gpu
#SBATCH --time=12:00:00
#SBATCH --export=NONE
#SBATCH --output=slurm-%A.out 
# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}
module load blink-pipeline-gpu/cristian-dev

OBSERVATION_ID=1293315072
SOLUTION_ID=1293310336

INPUT_DIR=/scratch/$PAWSEY_PROJECT/cdipietrantonio/$OBSERVATION_ID
INPUT_FILES="${INPUT_DIR}/combined/${OBSERVATION_ID}_*_ch*.dat"
METAFITS=$INPUT_DIR/$OBSERVATION_ID.metafits
SOL_FILE=$INPUT_DIR/$SOLUTION_ID.bin 
# SOL_FILE=/scratch/pawsey1154/cdipietrantonio/1276619416/1276625432.bin

OUTPUT_DIR=$MYSCRATCH/${OBSERVATION_ID}_4sec_int20ms_1200px
if ! [ -e $OUTPUT_DIR ]; then
  mkdir -p $OUTPUT_DIR
  # tells Lustre FS to only use the Flash pool (SSDs)
  # lfs setstripe -p flash $OUTPUT_DIR
fi

print_run `which blink_pipeline` -c 4 -C -1 -t 20ms  -o ${OUTPUT_DIR} -n 1200  -F 30 -M ${METAFITS}  -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1 -A 13,27,30,55,58,71,72,84,115  ${INPUT_FILES} 

