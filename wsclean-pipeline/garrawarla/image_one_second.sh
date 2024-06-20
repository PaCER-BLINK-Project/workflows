#!/bin/bash

# Loads all the needed software
module use /pawsey/mwa/software/python3/modulefiles
module use /scratch/director2183/cdipietrantonio/garrawarla/cotter/install/modulefiles
module load cfitsio/4.3.1 cuda/11.4.2 cmake/3.24.3

module load offline_correlator/v1.0.0
module load wsclean/2.9
module load cotter/devel
module load python/3.8.2 astropy

SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
OBSERVATIONS_ROOT_DIR=/scratch/mwavcs/msok/1276619416/combined #/group/director2183/cdipietrantonio/obs-data
WORK_DIR=${MYSCRATCH}/test-old-pipeline

# Include the MWA WSClean workflow functions
. "${SCRIPT_DIR}/../lib/mwa-wsclean-workflow.sh"

# Set Observation ID and GPS second to process
set_observation 1276619416 1276619418

download_metadata
download_calibration_data
fix_metadata 
run_correlator
run_cotter
run_wsclean

