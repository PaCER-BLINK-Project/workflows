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
module use /software/setonix/unsupported/
module load blink-pipeline-gpu/debug #dedisp-gpu

OBSERVATION_ID=1192477696
SOLUTION_ID=1192467680

INPUT_DIR=/scratch/pawsey1154/cdipietrantonio/1192477696 
INPUT_FILES="${INPUT_DIR}/combined/${OBSERVATION_ID}_119247770*_ch*.dat"
METAFITS=$INPUT_DIR/$OBSERVATION_ID.metafits
SOL_FILE=/scratch/pawsey1154/cdipietrantonio/${OBSERVATION_ID}/1192467680.bin

OUTPUT_DIR=$MYSCRATCH/${OBSERVATION_ID}_crab_images_8192_bugfixes
if ! [ -e $OUTPUT_DIR ]; then
  mkdir -p $OUTPUT_DIR
  # tells Lustre FS to only use the Flash pool (SSDs)
  # lfs setstripe -p flash $OUTPUT_DIR
fi
srun -u --gres=gpu:1 -n1 -c 16 `which blink_pipeline` -u  -c 8 -t 1s   -o ${OUTPUT_DIR} -n 8192 -M ${METAFITS} -r -s ${SOL_FILE} -b 0  ${INPUT_FILES} 
# srun -u  -n1 -c 64  `which blink_pipeline` -u  -c 8 -t 1s   -o ${OUTPUT_DIR} -n 8192 -M ${METAFITS} -r  -s ${SOL_FILE} -b 0  ${INPUT_FILES} 

