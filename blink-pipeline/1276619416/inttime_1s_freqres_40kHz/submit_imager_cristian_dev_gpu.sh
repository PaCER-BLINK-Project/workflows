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
module load msfitslib/master-ddop32m  blink-pipeline-gpu/cristian-dev
# module load rocm/6.3.2
INPUT_DIR=/scratch/$PAWSEY_PROJECT/cdipietrantonio/1276619416/combined
#module list
#[ -e ${INPUT_DIR}/combined.tar.gz ] || rclone copy cdipietrantonio:obs-1276619416/combined.tar.gz ${INPUT_DIR}
#cd $INPUT_DIR
#[ -e 1276619416_1276619420_ch133.dat ] || tar mxf combined.tar.gz
#cd - 
# Create a test directory, so test files do no pollute the build directory. 

INPUT_FILES="${INPUT_DIR}/1276619416_12766194*_ch*.dat"
METAFITS=/scratch/$PAWSEY_PROJECT/cdipietrantonio/1276619416/1276619416.metafits
SOL_FILE=${BLINK_TEST_DATADIR}/mwa/1276619416/1276625432.bin

OUTPUT_DIR=$MYSCRATCH/test_newcal #c2cdump
PERF="perf record -g -F 9000"
PYROCPROF=/software/projects/pawsey0001/cdipietrantonio/development/utils/apps/pyrocprof.py 
# module load arm-forge/24.0.3
export FORGE_DEBUG_SRUN_ARGS="%jobid% --gres=none -I -W0 --gpus=0 --overlap --distribution=cyclic"
module list
ldd `which blink_pipeline`
p_start_time=`date +%s`
#$PERF  `which blink_pipeline` -c 4 -C -1 -t 1s -o ${OUTPUT_DIR} -n 8192 -f -1 -F 30 -M ${METAFITS} -U 1592584240 -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1 -A 21,25,58,71,80,81,92,101,108,114,119,125 ${INPUT_FILES} 
 `which blink_pipeline` -u -c 4 -C -1 -t 1s  -o ${OUTPUT_DIR} -n 8192  -F 30 -M ${METAFITS}  -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1 -A 21,25,58,71,80,81,92,101,108,114,119,125 ${INPUT_FILES} 
    p_end_time=`date +%s`
    p_elapsed=$((p_end_time-p_start_time))
    echo "Pipeline took $p_elapsed seconds."
cd ${OUTPUT_DIR}
find . -name "*real.fits" > fits_list_all
avg_images fits_list_all avg_all.fits rms_all.fits -r 10000000.00
