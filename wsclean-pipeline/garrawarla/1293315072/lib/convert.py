from astropy.coordinates import EarthLocation,SkyCoord
from astropy.time import Time
from astropy import units as u
from astropy.coordinates import AltAz, ICRS

observing_location = EarthLocation(lat='52.2532', lon='351.63910339111703', height=100*u.m)  
observing_time = Time('2017-02-05 20:12:18')  
aa = AltAz(location=observing_location, obstime=observing_time)
print(aa)
coord = SkyCoord('4h42m', '-38d6m50.8s')
print(coord)
ra_dec_coord = coord.transform_to(aa)
print(ra_dec_coord)


def azel2radec(azimut, elevation):

    azel = [(azimut, elevation)]
    azelcoord  = SkyCoord(azel, frame=aa, unit=u.deg)
    radec_coord = azelcoord.transform_to(ICRS)
    ra = (radec_coord.ra * u.deg).value[0]
    dec = (radec_coord.dec * u.deg).value[0]
    return (ra, dec)

print(azel2radec(180.18095968, -0.34268787))
