#!/bin/bash

#SBATCH --partition=gpuq
#SBATCH --account=mwavcs
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=30
#SBATCH --time=04:00:00

# Loads all the needed software
module use /pawsey/mwa/software/python3/modulefiles
module use /scratch/director2183/cdipietrantonio/garrawarla/cotter/install/modulefiles
module load cfitsio/4.3.1 cuda/11.4.2 cmake/3.24.3

module load offline_correlator/v1.0.0
module load wsclean/2.9
module load cotter/devel
module load python/3.8.2 astropy

N_SECONDS=60
OBSERVATION_ID=1276619416

SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
OBSERVATIONS_ROOT_DIR=/scratch/mwavcs/msok/1276619416/combined #/group/director2183/cdipietrantonio/obs-data
WORK_DIR=${MYSCRATCH}/garrawarla-wsclean-workflow-obsid${OBSERVATION_ID}_${N_SECONDS}s

# Include the MWA WSClean workflow functions
. "${SCRIPT_DIR}/../lib/mwa-wsclean-workflow.sh"

# Set Observation ID and GPS second to process
START_GPSTIME=1276619418
END_GPSTIME=$(expr $START_GPSTIME + $N_SECONDS - 1 )
for CURRENT_GPSTIME in `seq $START_GPSTIME $END_GPSTIME`;
do 
echo $CURRENT_GPSTIME
continue
set_observation $OBSERVATION_ID $CURRENT_GPSTIME 
download_metadata
download_calibration_data
fix_metadata 
run_correlator
run_cotter
run_wsclean
done
