#!/bin/bash -e 
#SBATCH --account=pawsey1154-gpu
#SBATCH --gres=gpu:8
#SBATCH --partition=gpu
#SBATCH --time=12:00:00
#SBATCH --export=NONE
#SBATCH --output=slurm-%A.out 
# A nice way to execute a command and print the command line

module use /software/setonix/unsupported/
module load blink-pipeline-gpu/debug

. ../common.sh

OBSERVATION_ID=1192477696
SOLUTION_ID=1192467680
OUTPUT_SUFFIX=_images_1024
# SECONDS_TO_PROCESS=4
# DEBUG_LINE="gdb --args"
IMAGING=1
run_blink -u -c 4  -t 1s  -n 1024

