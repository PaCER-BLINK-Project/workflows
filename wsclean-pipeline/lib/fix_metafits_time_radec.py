#!/usr/bin/env python3

import astropy.io.fits as pyfits
import math 
from array import *
import numpy as np
import sys
import argparse

from astropy.coordinates import EarthLocation,SkyCoord
from astropy.time import Time
from astropy import units as u
from astropy.coordinates import AltAz, ICRS





def azel2radec(azimut, elevation, time_unix):
    mwa_location = EarthLocation(lat='-26.70331', lon='116.6708', height=377*u.m)
    observing_time = Time(time_unix, format='unix')
    MWA_altaz = AltAz(location=mwa_location, obstime=observing_time)
    azel = [(azimut, elevation)]
    azelcoord  = SkyCoord(azel, frame=MWA_altaz, unit=u.deg)
    radec_coord = azelcoord.transform_to(ICRS)
    ra = (radec_coord.ra * u.deg).value[0]
    dec = (radec_coord.dec * u.deg).value[0]
    return (ra, dec)
    
#

#      t_dtm=`echo $t | awk '{print substr($1,1,8)"_"substr($1,9);}'`
#      t_dateobs=`echo $t | awk '{print substr($1,1,4)"-"substr($1,5,2)"-"substr($1,7,2)"T"substr($1,9,2)":"substr($1,11,2)":"substr($1,13,2);}'`
#      t_ux=`date2date -ut2ux=${t_dtm} | awk '{print $3;}'`
#      t_gps=`ux2gps! $t_ux`
#
#      echo "azh2radec $t_ux mwa $azim $alt"
#      ra=`azh2radec $t_ux mwa $azim $alt | awk '{print $4;}'`
#      dec=`azh2radec $t_ux mwa $azim $alt | awk '{print $6;}'`
#   
#      cp $metafits ${t}.metafits
#      echo "python ${PYTHON_SCRIPTS_DIR}/fix_metafits_time_radec.py ${t}.metafits $t_dateobs $t_gps $ra $dec --n_channels=${n_channels}"
#      python ${PYTHON_SCRIPTS_DIR}/fix_metafits_time_radec.py ${t}.metafits $t_dateobs $t_gps $ra $dec  --n_channels=${n_channels}
#
#
#
#
#
#

if __name__ == '__main__':
   parser = argparse.ArgumentParser(prog='fix_metadata.py', description='Updates the metadata file to match the current second of MWA observation.') 
   parser.add_argument('-c','--n_channels','--n_chans', dest="n_channels",default=768, help="Number of channels [default %default]", type=int)
   parser.add_argument('-t','--n_scans','--n_timesteps', dest="n_timesteps",default=1, help="Number of timesteps [default %default]", type=int)
   parser.add_argument('-i','--inttime','--inttime_sec', dest="inttime",default=4, help="Integration time in seconds [default %default]", type=int)
   parser.add_argument('-d','--datetime', dest="datetime", required=True, help="Current date and time to witch the metadata refers to (in Unix time).", type=int)
   parser.add_argument('metafits', metavar='metafits', type=str, nargs=1)
   args = vars(parser.parse_args())
   
   fitsname = args['metafits'] 
   fits = pyfits.open(fitsname)
      
   alt =  fits[0].header['ALTITUDE']
   azim = fits[0].header['AZIMUTH']
   ra, dec = azel2radec(azim, alt, args['datetime'])
   #fits[0].header['DATE-OBS']  = dateobs
   #fits[0].header['GPSTIME']   = int(gps)
   fits[0].header['RA']        = float(ra)
   fits[0].header['DEC']       = float(dec)
   fits[0].header['NSCANS']    = args['n_timesteps']
   fits[0].header['INTTIME']   = args['inttime']
   fits[0].header['NCHANS']    = args['n_channels']

   print("Writing fits %s" % (fitsname))
   fits.writeto(fitsname, overwrite=True) 


