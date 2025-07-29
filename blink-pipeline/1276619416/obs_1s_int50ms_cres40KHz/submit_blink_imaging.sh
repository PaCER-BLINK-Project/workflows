#!/bin/bash -e 
#SBATCH --account=pawsey1154-gpu
#SBATCH --gres=gpu:4
#SBATCH --partition=gpu
#SBATCH --time=11:00:00
#SBATCH --export=NONE
#SBATCH --exclusive

# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}
module use /software/setonix/unsupported
module load  blink-pipeline-gpu/cristian-dev
module load omniperf/1.0.10
#INPUT_DIR=/scratch/mwavcs/msok/1276619416/combined # ${MYSCRATCH}/obs-1276619416
INPUT_DIR=${MYSCRATCH}/1276619416/combined
# Create a test directory, so test files do no pollute the build directory. 

INPUT_FILES="${INPUT_DIR}/1276619416_1276619418_ch*.dat"
METAFITS=${MYSCRATCH}/1276619416/1276619416.metafits #"$BLINK_TEST_DATADIR/mwa/1276619416/20200619163000.metafits"
SOL_FILE=${BLINK_TEST_DATADIR}/mwa/1276619416/1276625432.bin

OUTPUT_DIR=/nvme/1276619416_1276619418_20ms_40KHz
[ -e $OUTPUT_DIR ] || mkdir $OUTPUT_DIR
# lfs setstripe -p flash $OUTPUT_DIR

# module load rocm/6.2.0
PYROCPROF=/software/projects/pawsey0001/cdipietrantonio/development/utils/apps/pyrocprof.py 
# module load arm-forge/24.0.3


CL="`which blink_pipeline` -c 4  -t 20ms -o ${OUTPUT_DIR} -n 1200  -F 30 -M ${METAFITS} -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -V 1 -A 21,25,58,71,80,81,92,101,108,114,119,125 ${INPUT_FILES}" 
module load py-matplotlib/3.8.1 
#record_energy.py -t0.5 -p -- $CL
omniperf  profile   -n blink_pipeline -- $CL 
omniperf analyze -p workloads/blink_pipeline/mi200/ > correlator_analyze.txt
# rm -r $OUTPUT_DIR

