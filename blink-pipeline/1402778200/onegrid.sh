#!/bin/bash -e 
# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}

module load rclone/1.63.1
module load msfitslib/master-ddop32m  blink-pipeline-gpu/cristian-dev # blink-pipeline-gpu/onegrid

ROOT_DIR=/scratch/mwavcs/cdipietrantonio/mwax2obs
INPUT_DIR=$ROOT_DIR
#module list
#[ -e ${INPUT_DIR}/combined.tar.gz ] || rclone copy cdipietrantonio:obs-1276619416/combined.tar.gz ${INPUT_DIR}
#cd $INPUT_DIR
#[ -e 1276619416_1276619420_ch133.dat ] || tar mxf combined.tar.gz
#cd - 
# Create a test directory, so test files do no pollute the build directory. 

# METAFITS=/scratch/pawsey1154/msok/1192477696/combined/1192477696.metafits ##$ROOT_DIR/1402778200.metafits
 METAFITS=$ROOT_DIR/1402778200.metafits
# SOL_FILE=${BLINK_TEST_DATADIR}/mwa/1276619416/1276625432.bin
OUTPUT_DIR=$MYSCRATCH/1402778200_imag
mkdir -p $OUTPUT_DIR
lfs setstripe -p flash $OUTPUT_DIR

seconds_to_process=8

filelist=(`ls -1 $INPUT_DIR`)
n_files=${#filelist[@]}
for i in `seq 0 $((n_files - 1))`;
do
filelist[$i]="$INPUT_DIR/${filelist[$i]}"
done

processed=0
while (( processed < n_files )); 
do
#CAL="-b0 -s /scratch/mwavcs/smcsweeney/J1912_test/1402752880_local_gleam_model_solutions_initial_ref.bin "
n_files_to_process=$((seconds_to_process * 24))
INPUT_FILES=${filelist[@]:processed:n_files_to_process}
BLINK_COMMAND_LINE="`which blink_pipeline` -u -c 4 -C -1 -t 1.00s -o ${OUTPUT_DIR} -n 8192  -F 30 -M ${METAFITS} ${CAL} -w N -v 100 -r -L -G  -r -V 1 ${INPUT_FILES}" 
gdb --args $BLINK_COMMAND_LINE
#sbatch --account=pawsey1154-gpu --gres=gpu:1 --gpu-bind=closest --partition=gpu --time=10:00:00 --export=ALL  --wrap "${BLINK_COMMAND_LINE}"
processed=$((processed + n_files_to_process))
done

#

