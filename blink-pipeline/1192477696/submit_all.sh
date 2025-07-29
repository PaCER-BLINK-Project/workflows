#!/bin/bash -e 
#SBATCH --account=pawsey1154-gpu
#SBATCH --gres=gpu:8
#SBATCH --partition=gpu
#SBATCH --time=12:00:00
#SBATCH --export=NONE
#SBATCH --output=slurm-%A.out 
# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}
module use /software/setonix/unsupported
module load blink-pipeline-gpu/debug

OBSERVATION_ID=1192477696
SOLUTION_ID=1192467680

INPUT_DIR=/scratch/pawsey1154/cdipietrantonio/1192477696
# INPUT_FILES="${INPUT_DIR}/combined/${OBSERVATION_ID}_119247770*_ch*.dat"
METAFITS=$INPUT_DIR/$OBSERVATION_ID.metafits
SOL_FILE=/scratch/pawsey1154/cdipietrantonio/${OBSERVATION_ID}/1192467680.bin

OUTPUT_DIR=$MYSCRATCH/${OBSERVATION_ID}_crab_1sec
if ! [ -e $OUTPUT_DIR ]; then
  mkdir -p $OUTPUT_DIR
  # tells Lustre FS to only use the Flash pool (SSDs)
  # lfs setstripe -p flash $OUTPUT_DIR
fi

seconds_to_process=100

filelist=(`ls -1 $INPUT_DIR/combined`)
n_files=${#filelist[@]}
for i in `seq 0 $((n_files - 1))`;
do
filelist[$i]="$INPUT_DIR/combined/${filelist[$i]}"
done

processed=0
count=0
while (( processed < n_files )); 
do
n_files_to_process=$((seconds_to_process * 24))
INPUT_FILES=${filelist[@]:processed:n_files_to_process}
BLINK_COMMAND_LINE="`which blink_pipeline` -c 4 -t 20ms  -o ${OUTPUT_DIR}_newpart${count} -n 1000 -M ${METAFITS} -r -s ${SOL_FILE} -b 0 -S 4.5 -D55:60:1 $INPUT_FILES"
#sbatch --account=mwavcs-gpu --gres=gpu:8 --partition=mwa-gpu --time=24:00:00 --export=ALL  --wrap "srun -c 64 -n1 ${BLINK_COMMAND_LINE}"
sbatch --account=pawsey1154-gpu --gres=gpu:8 --partition=gpu --time=04:00:00 --export=ALL  --wrap "srun -c 64 -n1 ${BLINK_COMMAND_LINE}"
processed=$((processed + n_files_to_process))
count=$((count + 1))
done

