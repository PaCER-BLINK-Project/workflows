# How to fix metafits files

This is a snipped taken from the SMART pipeline. Keeping it for future integration in our own code.

```
while read line # example 
do
   t=$line
   
   if [[ ! -s ${t}.metafits || $force -gt 0 ]]; then    
      t_dtm=`echo $t | awk '{print substr($1,1,8)"_"substr($1,9);}'`
      t_dateobs=`echo $t | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)"T"substr($1,9,2)":"substr($1,11,2)":"substr($1,13,2);}'`
      t_ux=`date2date -ut2ux=${t_dtm} | awk '{print $3;}'`
      t_gps=`ux2gps! $t_ux`

      echo "azh2radec $t_ux mwa $azim $alt"
      ra=`azh2radec $t_ux mwa $azim $alt | awk '{print $4;}'`
      dec=`azh2radec $t_ux mwa $azim $alt | awk '{print $6;}'`
   
      cp $metafits ${t}.metafits
      print_run python3 fix_metafits_time_radec.py ${t}.metafits $t_dateobs $t_gps $ra $dec  --n_channels=${n_channels}
   else
      echo "INFO : ${t}.metafits already exists -> ignored"
   fi   
done < timestamps.txt
```

