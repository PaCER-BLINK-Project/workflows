#!/bin/bash

#SBATCH --partition=gpuq
#SBATCH --account=mwavcs
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=30
#SBATCH --time=04:00:00


export OBSERVATION_ID=1293315072
export TIME_RESOLUTION="20ms"

N_SECONDS=2
N_SECONDS_PER_BATCH=1
# Set Observation ID and GPS second to process
START_GPSTIME=1293315074
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
