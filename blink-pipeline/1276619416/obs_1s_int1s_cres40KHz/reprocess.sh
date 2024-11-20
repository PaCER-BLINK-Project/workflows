#!/bin/bash

cd $idir
./build_cristian.sh gpu
cd $tdir
./submit_imager_cristian_dev.sh 
