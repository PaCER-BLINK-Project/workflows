#!/bin/bash

#SBATCH --partition=gpuq
#SBATCH --account=mwavcs
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=40
#SBATCH --time=24:00:00

# Loads all the needed software
module use /pawsey/mwa/software/python3/modulefiles
module use /pawsey/mwa/software/centos7.6/cdipietrantonio/install/modulefiles
source /pawsey/mwa/software/centos7.6/cdipietrantonio/setup.sh

# Include the MWA WSClean workflow functions
. "lib/mwa-wsclean-workflow.sh"


TIME_RESOLUTION=${TIME_RESOLUTION:-"20ms"}

if [ "${TIME_RESOLUTION}" = "50ms" ]; then
module load offline_correlator/50ms
elif [ "${TIME_RESOLUTION}" = "20ms" ]; then
module load offline_correlator/20ms
else
module load offline_correlator/v1.0.0
fi
module load cotter/devel
module load python/3.8.2 astropy
#spack load birli

# module load wsclean/2.9
#module load cfitsio/4.3.1 cuda/11.4.2 cmake/3.24.3

set_time_resolution ${TIME_RESOLUTION}

OBSERVATION_ID=${OBSERVATION_ID:-1293315072}
OBSERVATIONS_ROOT_DIR=/scratch/mwavcs/msok/1293315072/combined #/scratch/director2183/cdipietrantonio/${OBSERVATION_ID}/combined
WORK_DIR=/scratch/director2183/cdipietrantonio/garrawarla-wsclean-workflow-natural-obsid1293315072_20ms_method2

# Set Observation ID and GPS second to process
START_GPSTIME=${START_GPSTIME:-1293315075}
END_GPSTIME=${END_GPSTIME:-${START_GPSTIME}}

for CURRENT_GPSTIME in `seq $START_GPSTIME $END_GPSTIME`;
do
echo ${CURRENT_GPSTIME}
set_observation ${OBSERVATION_ID} ${CURRENT_GPSTIME}
set_time_resolution ${TIME_RESOLUTION} 
download_metadata
download_calibration_data
fix_metadata 
run_correlator
run_cotter
run_wsclean 1200 0.006 "natural"
done
