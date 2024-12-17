#!/bin/bash

#SBATCH --partition=gpuq
#SBATCH --account=mwavcs
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=30
#SBATCH --time=04:00:00


export OBSERVATION_ID=1276619416
export TIME_RESOLUTION="1s"

N_SECONDS=4600
N_SECONDS_PER_BATCH=100
# Set Observation ID and GPS second to process
START_GPSTIME=1276619418
LAST_GPSTIME=$(expr $START_GPSTIME + $N_SECONDS - 1 )
while ((START_GPSTIME < LAST_GPSTIME ));
do 
END_GPSTIME=$((START_GPSTIME + N_SECONDS_PER_BATCH - 1))
if [ $END_GPSTIME -gt $LAST_GPSTIME ]; then
END_GPSTIME=$LAST_GPSTIME
fi
export START_GPSTIME
export END_GPSTIME
sbatch --export=ALL ./image_one_second.sh
START_GPSTIME=$((START_GPSTIME + N_SECONDS_PER_BATCH))
done
