#!/bin/bash

# Loads all the needed software
module use /pawsey/mwa/software/python3/modulefiles
module use /pawsey/mwa/software/centos7.6/cdipietrantonio/install/modulefiles
source /pawsey/mwa/software/centos7.6/cdipietrantonio/setup.sh


module load offline_correlator/v1.0.0
module load cotter/devel
module load python/3.8.2 astropy
#spack load birli

#module load wsclean/2.9
#module load cfitsio/4.3.1 cuda/11.4.2 cmake/3.24.3
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
OBSERVATIONS_ROOT_DIR=/scratch/mwavcs/msok/1276619416/combined #/group/director2183/cdipietrantonio/obs-data
if [ -d /nvmetmp ]; then
WORK_DIR=/nvmetmp/test-old-pipeline
else
WORK_DIR=${MYSCRATCH}/test-old-pipeline
fi
# Include the MWA WSClean workflow functions
. "${SCRIPT_DIR}/../lib/mwa-wsclean-workflow.sh"

# Set Observation ID and GPS second to process
set_observation 1276619416 1276619418

p_start_time=`date +%s`

download_metadata
download_calibration_data
fix_metadata 
run_correlator
run_cotter

# run_birli

# run_wsclean <image_size> <pix_scale> <weighting>
run_wsclean 1024 0.08 "briggs 0"

p_end_time=`date +%s`
p_elapsed=$((p_end_time-p_start_time))

echo "Pipeline took $p_elapsed seconds to execute."
