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
from datetime import datetime, timedelta, tzinfo, timezone

def gps_to_unix(gps_time):
    return (315964800 + gps_time - 18)

def unix_to_utc(unix_time):
    dt_obj = datetime.fromtimestamp(unix_time)
    dt_obj = dt_obj.astimezone(timezone.utc)
    return dt_obj.strftime('%Y%m%d%H%M%S')


def azel2radec(azimut, elevation, time_unix):
    mwa_location = EarthLocation.from_geodetic(lat=-26.70331*u.deg, lon=116.6708*u.deg, height=377*u.m)
    # need time in local time?
    local_time = (datetime.fromtimestamp(time_unix) - timedelta(hours=8)).isoformat()
    print(local_time)
    observing_time = Time(local_time, format='isot') #time_unix, format='unix')
    MWA_altaz = AltAz(location=mwa_location, obstime=observing_time)
    azel = [(azimut, elevation)]
    azelcoord  = SkyCoord(azel, frame=MWA_altaz, unit=u.deg)
    radec_coord = azelcoord.transform_to(ICRS)
    ra = (radec_coord.ra * u.deg).value[0]
    dec = (radec_coord.dec * u.deg).value[0]
    return (ra, dec)
    

if __name__ == '__main__':
   parser = argparse.ArgumentParser(prog='fix_metadata.py', description='Updates the metadata file to match the current second of MWA observation.') 
   parser.add_argument('-c','--n_channels','--n_chans', dest="n_channels",default=768, help="Number of channels [default %default]", type=int)
   parser.add_argument('-t','--n_scans','--n_timesteps', dest="n_timesteps",default=1, help="Number of timesteps [default %default]", type=int)
   parser.add_argument('-i','--inttime','--inttime_sec', dest="inttime",default=4, help="Integration time in seconds [default %default]", type=float)
   parser.add_argument('-g','--gpstime', dest="gpstime", required=True, help="GPS time of current second being processed.", type=int)
   parser.add_argument('-o','--outdir', dest="outdir", help="Output directory where to save the new metafits.", default=".", type=str)
   parser.add_argument('metafits', metavar='metafits', type=str, nargs=1)
   args = vars(parser.parse_args())
   
   input_fitsname = args['metafits'][0] 
   fits = pyfits.open(input_fitsname)
      
   alt =  fits[0].header['ALTITUDE']
   azim = fits[0].header['AZIMUTH']
   unix_time = gps_to_unix(args['gpstime'])
   utc_time = unix_to_utc(unix_time)
   ra, dec = azel2radec(azim, alt, unix_time)
   #fits[0].header['DATE-OBS']  = dateobs
   fits[0].header['GPSTIME']   = args['gpstime']
   fits[0].header['RA']        = float(ra)
   fits[0].header['DEC']       = float(dec)
   fits[0].header['NSCANS']    = args['n_timesteps']
   fits[0].header['INTTIME']   = args['inttime']
   fits[0].header['NCHANS']    = args['n_channels']
   
   out_fitsname = f"{args['outdir']}/{utc_time}.metafits"
   print("Writing fits %s" % (out_fitsname))
   fits.writeto(out_fitsname, overwrite=True)


