#!/bin/bash

module load msfitslib/master-rmfufbl

OUTPUT_DIR=${MYSCRATCH}/1276619416_1276619418_4096_images_gpu_orig
cd ${OUTPUT_DIR}
find . -name "*test_image_time000000_ch*_real.fits" > fits_list_all
while read filename
do
calcfits_bg $filename = "../1276619416_1276619418_4096_images_gpu_main_updated/$filename" 
done < fits_list_all > comparison_out.txt
num_images=`wc -l fits_list_all | cut -f1 -d' '`
found_equal=`grep -ce "Images are EQUAL" comparison_out.txt`
if [ $num_images -eq $found_equal ]; then
    echo "All images are equal."
else
    echo "Some images different, retrieving max diffs..."
    grep -e "maximum difference = " comparison_out.txt | cut -f2 -d= | cut -f1 -da > max_diffs.txt
    avg_diff=`python3 -c 'max_diffs = [float(line) for line in open("max_diffs.txt", "r")]; print(sum(max_diffs)/len(max_diffs))'`
    echo "Average difference is $avg_diff"
fi
