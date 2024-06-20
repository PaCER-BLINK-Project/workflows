#!/opt/caastro/ext/anaconda/bin/python

import astropy.io.fits as pyfits
import math 
from array import *
import numpy as np
import sys
import os
import errno
import getopt
import optparse
from optparse import OptionParser,OptionGroup


# global parameters :
debug=0
fitsname="file.fits"
out_fitsname="scaled.fits"
do_show_plots=0
do_gif=0

center_x=1025
center_y=1025
radius=600

def mkdir_p(path):
   try:
      os.makedirs(path)
   except OSError as exc: # Python >2.5
      if exc.errno == errno.EEXIST:
         pass
      else: raise

# parser.add_option('-c','--n_channels','--n_chans',dest="n_channels",default=768, help="Number of channels [default %default]", type="int")
# parser.add_option('-t','--n_scans','--n_timesteps',dest="n_timesteps",default=1, help="Number of timesteps [default %default]", type="int")
# parser.add_option('-i','--inttime','--inttime_sec',dest="inttime",default=4, help="Integration time in seconds [default %default]", type="int")

                                            
def parse_options(idx):
   parser=optparse.OptionParser()
   parser.set_usage("""fix_metafits_time_radec.py""")
   parser.add_option("--n_channels","--n_chan","--n_ch","-n",dest="n_channels",default=768,help="Number of channels [default: %default]",type="int")
   parser.add_option('-t','--n_scans','--n_timesteps',dest="n_timesteps",default=1, help="Number of timesteps [default %default]", type="int")
   (options,args)=parser.parse_args(sys.argv[idx:])
   
   return (options, args)


def fix_metafits( fitsname , dateobs, gps, ra, dec, n_chans=768, n_scans=1, inttime=4 ) :
   fits = pyfits.open(fitsname)
      
   fix_metafits_base( fits , fitsname, dateobs, gps, ra, dec, n_chans=n_chans, n_scans=n_scans, inttime=inttime ) 
   

def fix_metafits_base( fits , fitsname, dateobs, gps, ra, dec, n_chans=768, n_scans=1, inttime=1 ) :
   # fits = pyfits.open(fitsname)

   #fits[0].header['DATE-OBS']  = dateobs
   #fits[0].header['GPSTIME']   = int(gps)
   #fits[0].header['RA']        = float(ra)
   #fits[0].header['DEC']       = float(dec)
   fits[0].header['NSCANS']    = n_scans
   fits[0].header['INTTIME']   = inttime
   fits[0].header['NCHANS']    = n_chans

   print("Writing fits %s" % (fitsname))
   fits.writeto( fitsname, overwrite=True ) 


if __name__ == '__main__':
   if len(sys.argv) < 2:
      exit(2)
 
   fitsname = sys.argv[1]

   dateobs=0#sys.argv[2]
   gps=0#sys.argv[3]
   ra=0#sys.argv[4]
   dec=0#sys.argv[5]
   #
   (options, args) = parse_options(2)
   
   n_scans = options.n_timesteps
   n_chans=options.n_channels
   inttime=1

   print("####################################################")
   print("fitsname       = %s"   % fitsname)
   print("n_channels     = %d" % (options.n_channels))
   print("inttime        = %d" % (inttime))
   print("####################################################")

   fix_metafits( fitsname, dateobs, gps, ra, dec, n_chans=n_chans, n_scans=n_scans, inttime=inttime )

