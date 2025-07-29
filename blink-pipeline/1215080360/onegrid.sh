#!/bin/bash -e 
# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}
module use /software/setonix/unsupported
module load rclone/1.63.1
module load msfitslib/master-ddop32m blink-pipeline-gpu/cristian-dev
ROOT_DIR=$MYSCRATCH/1215080360
INPUT_DIR=$ROOT_DIR/combined
#module list
#[ -e ${INPUT_DIR}/combined.tar.gz ] || rclone copy cdipietrantonio:obs-1276619416/combined.tar.gz ${INPUT_DIR}
#cd $INPUT_DIR
#[ -e 1276619416_1276619420_ch133.dat ] || tar mxf combined.tar.gz
#cd - 
# Create a test directory, so test files do no pollute the build directory. 

METAFITS=$ROOT_DIR/1215080360.metafits
SOL_FILE=$ROOT_DIR/1215119872.bin
OUTPUT_DIR=$MYSCRATCH/1215080360/images_1second
mkdir -p $OUTPUT_DIR
lfs setstripe -p flash $OUTPUT_DIR

seconds_to_process=100

filelist=(`ls -1 $INPUT_DIR | grep -e ".dat"`)
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
BLINK_COMMAND_LINE="`which blink_pipeline` -u -c 4 -C -1 -t 1.00s -o ${OUTPUT_DIR} -n 8192  -F 30 -M ${METAFITS}  -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1 -A  22,32,79 ${INPUT_FILES}" 
sbatch --account=pawsey1154-gpu --gres=gpu:1 --gpu-bind=closest --partition=gpu --time=10:00:00 --export=ALL  --wrap "${BLINK_COMMAND_LINE}"
processed=$((processed + n_files_to_process))
done

