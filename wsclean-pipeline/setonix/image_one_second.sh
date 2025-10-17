#!/bin/bash

#SBATCH --partition=debug
#SBATCH --account=pawsey1154
#SBATCH --cpus-per-task=64
#SBATCH --time=01:00:00

# Loads all the needed software
# Include the MWA WSClean workflow functions
. "../lib/mwa-wsclean-workflow.sh"


TIME_RESOLUTION=${TIME_RESOLUTION:-"1s"}
module load python/3.11.6 cotter/latest wsclean/3.4-idg-everybeam  # cotter/v4.5 
module load blink-correlator/master
#spack load birli


set_time_resolution ${TIME_RESOLUTION}

OBSERVATION_ID=${OBSERVATION_ID:-1276619416}
OBSERVATIONS_ROOT_DIR=${MYSCRATCH}/${OBSERVATION_ID}/combined
WORK_DIR=${MYSCRATCH}/${OBSERVATION_ID}_wscleanpipeline

# Set Observation ID and GPS second to process
START_GPSTIME=${START_GPSTIME:-1276619418}
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
run_wsclean 1024 0.006 "natural"
done
