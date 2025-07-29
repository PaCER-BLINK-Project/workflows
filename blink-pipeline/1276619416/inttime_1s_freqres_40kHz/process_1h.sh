#!/bin/bash -e 
#SBATCH --account=director2183-gpu
#SBATCH --gres=gpu
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu
#SBATCH --time=24:00:00
#SBATCH --export=NONE
#SBATCH --output=logs/slurm-%A.out 
# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}

module load rclone/1.63.1
module use /software/projects/director2183/cdipietrantonio/setonix/2024.05/modules/zen3/gcc/12.2.0
module use /software/projects/director2183/cdipietrantonio/setonix/2024.05/development/for-marcin/modulefiles

module load msfitslib/master-ddop32m blink-pipeline/cristian-dev

INPUT_DIR=/scratch/director2183/cdipietrantonio/1276619416/combined
METAFITS=/scratch/director2183/cdipietrantonio/1276619416/1276619416.metafits
SOL_FILE=${BLINK_TEST_DATADIR}/mwa/1276619416/1276625432.bin
OUTPUT_DIR=$MYSCRATCH/test_flatten_1276619416_1.5h_1s_8192px_testrun
seconds_to_process=2 #100

filelist=(`ls -1 $INPUT_DIR`)
n_files=${#filelist[@]}
for i in `seq 0 $((n_files - 1))`;
do
filelist[$i]="$INPUT_DIR/${filelist[$i]}"
done

processed=0
while (( processed < n_files )); 
do
n_files_to_process=$((seconds_to_process * 24))
INPUT_FILES=${filelist[@]:processed:n_files_to_process}

BLINK_COMMAND_LINE="blink_pipeline -u -c 4 -C -1 -t 1.00s -o ${OUTPUT_DIR} -n 8192  -F 30 -M ${METAFITS}  -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1 -A 21,25,58,71,80,81,92,101,108,114,119,125 ${INPUT_FILES}" 

# --output=logs/slurm-%A.out
sbatch --account=director2183-gpu --gres=gpu:1 --partition=gpu --time=24:00:00 --export=ALL  --wrap "${BLINK_COMMAND_LINE}" 
exit
processed=$((processed + n_files_to_process))
done

#
