#!/bin/bash -e 
#SBATCH --account=director2183-gpu
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
module use /software/projects/director2183/cdipietrantonio/setonix/2024.05/modules/zen3/gcc/12.2.0
module load msfitslib/master-rmfufbl blink-pipeline-gpu/cristian-dev

INPUT_DIR=/scratch/mwavcs/msok/1141224136/combined
INPUT_FILES="${INPUT_DIR}/1141224136_*_ch*.dat"
METAFITS=/scratch/director2183/cdipietrantonio/1141224136/1141224136.metafits
SOL_FILE=/scratch/director2183/cdipietrantonio/1141224136/1141222488.bin 

OUTPUT_DIR=$MYSCRATCH/1141224136_300sec_int20ms_1024px
if ! [ -e $OUTPUT_DIR ]; then
  mkdir -p $OUTPUT_DIR
  # tells Lustre FS to only use the Flash pool (SSDs)
  lfs setstripe -p flash $OUTPUT_DIR
fi

print_run  `which blink_pipeline` -c 4 -C -1 -t 20ms  -o ${OUTPUT_DIR} -n 1024 -F 30 -M ${METAFITS}  -w N -v 100 -r -L -G -s ${SOL_FILE} -b 0  -r -V 1  ${INPUT_FILES} 

