#!/bin/bash

#SBATCH --partition=debug
#SBATCH --cpus-per-task=8
#SBATCH --time=15:00:00
#SBATCH --account=director2183

module load msfitslib/master-ddop32m

find . -name "*real.fits" > fits_list_all
avg_images fits_list_all avg_all.fits rms_all.fits -r 10000000.00

