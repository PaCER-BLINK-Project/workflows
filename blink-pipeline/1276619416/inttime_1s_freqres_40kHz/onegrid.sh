#!/bin/bash -e 
# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}
module use /software/setonix/unsupported
module load rclone/1.63.1
module load msfitslib/master-ddop32m blink-pipeline-gpu/onegrid
INPUT_DIR=$MYSCRATCH/1276619416/combined
#module list
#[ -e ${INPUT_DIR}/combined.tar.gz ] || rclone copy cdipietrantonio:obs-1276619416/combined.tar.gz ${INPUT_DIR}
#cd $INPUT_DIR
#[ -e 1276619416_1276619420_ch133.dat ] || tar mxf combined.tar.gz
#cd - 
# Create a test directory, so test files do no pollute the build directory. 

METAFITS=$MYSCRATCH/1276619416/1276619416.metafits
SOL_FILE=${BLINK_TEST_DATADIR}/mwa/1276619416/1276625432.bin
OUTPUT_DIR=$MYSCRATCH/one_grid_4444600s_fixcal
mkdir -p $OUTPUT_DIR
lfs setstripe -p flash $OUTPUT_DIR

seconds_to_process=100

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
BLINK_COMMAND_LINE="`which blink_pipeline` -u -c 4 -C -1 -t 1.00s -o ${OUTPUT_DIR} -n 8192  -F 30 -M ${METAFITS}  -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1 -A 21,25,58,71,80,81,92,101,108,114,119,125 ${INPUT_FILES}" 
sbatch --account=pawsey1154-gpu --gres=gpu:1 --gpu-bind=closest --partition=gpu --time=10:00:00 --export=ALL  --wrap "${BLINK_COMMAND_LINE}"
processed=$((processed + n_files_to_process))
done

