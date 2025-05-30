#!/bin/bash -e 
#SBATCH --account=director2183-gpu
#SBATCH --gres=gpu
#SBATCH --partition=gpu
##SBATCH --time=24:00:00
#SBATCH --export=NONE

# A nice way to execute a command and print the command line
function print_run {
	echo "Executing $@"
	$@
}

module load rclone/1.63.1
module load msfitslib/master-rmfufbl blink-pipeline-gpu/cristian-dev
#INPUT_DIR=/scratch/mwavcs/msok/1276619416/combined # ${MYSCRATCH}/obs-1276619416
INPUT_DIR=/scratch/mwavcs/msok/1276619416/combined
#module list
#[ -e ${INPUT_DIR}/combined.tar.gz ] || rclone copy cdipietrantonio:obs-1276619416/combined.tar.gz ${INPUT_DIR}
#cd $INPUT_DIR
#[ -e 1276619416_1276619420_ch133.dat ] || tar mxf combined.tar.gz
#cd - 
# Create a test directory, so test files do no pollute the build directory. 

INPUT_FILES="${INPUT_DIR}/1276619416_1276619418_ch*.dat"
METAFITS=/scratch/director2183/cdipietrantonio/test-old-pipeline/1276619416/metadata/1276619416.metafits #"$BLINK_TEST_DATADIR/mwa/1276619416/20200619163000.metafits"
SOL_FILE=${BLINK_TEST_DATADIR}/mwa/1276619416/1276625432.bin

OUTPUT_DIR=${MYSCRATCH}/1276619416_1276619418_50ms_40KHz
OUTPUT_DIR=/nvme/1276619416_1276619418_50ms_40KHz
# module load rocm/6.2.0
PERF="perf record -g -F 9000"
PYROCPROF=/software/projects/pawsey0001/cdipietrantonio/development/utils/apps/pyrocprof.py 
# module load arm-forge/24.0.3
export FORGE_DEBUG_SRUN_ARGS="%jobid% --gres=none -I -W0 --gpus=0 --overlap --distribution=cyclic"

$PERF  `which blink_pipeline` -c 4 -C -1 -t 1s -o ${OUTPUT_DIR} -n 8192 -f -1 -F 30 -M ${METAFITS} -U 1592584240 -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1 -A 21,25,58,71,80,81,92,101,108,114,119,125 ${INPUT_FILES} 
#  `which blink_pipeline` -c 4 -C -1 -t 50ms -o ${OUTPUT_DIR} -n 512 -f -1 -F 30 -M ${METAFITS} -U 1592584240 -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1 -A 21,25,58,71,80,81,92,101,108,114,119,125 ${INPUT_FILES} 

cd ${OUTPUT_DIR}
find . -name "*real.fits" > fits_list_all
avg_images fits_list_all avg_all.fits rms_all.fits -r 10000000.00

cp $OUTPUT_DIR/avg_all.fits $MYSCRATCH/output_all_channels_susmita.fits
#calcfits_bg avg_all.fits = ${BLINK_TEST_DATADIR}/mwa/1276619416/results/full_imaging/avg_all.fits 
