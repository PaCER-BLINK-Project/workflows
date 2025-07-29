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
module use /software/setonix/unsupported/
module load blink-pipeline-gpu/debug

. common.sh

OBSERVATION_ID=1192477696
SOLUTION_ID=1192467680
OUTPUT_SUFFIX=_crab_4
SECONDS_TO_PROCESS=4

DEBUG_LINE="gdb --args"

run_blink -c 4 -t 20ms -n 1000 -S 4.5 -D50:60:1

