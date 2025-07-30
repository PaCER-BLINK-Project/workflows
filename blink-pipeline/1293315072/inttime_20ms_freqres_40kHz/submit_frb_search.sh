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

CURRENT_DIR=`pwd`

. $CURRENT_DIR/../../common.sh

OBSERVATION_ID=1293315072
SOLUTION_ID=1293310336
OUTPUT_SUFFIX=_b0950_candidates
SECONDS_TO_PROCESS=4
SRUN_LINE="srun -u -n1 --gres=gpu:1"
DEBUG_LINE="gdb --args"

print_run run_blink -c 4 -S 5.5 -D 2.97:4:0.1 -t 20ms -n 1200 -A 13,27,30,55,58,71,72,84,115
