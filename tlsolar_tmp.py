#!/usr/bin/python3
# https://matplotlib.org/faq/usage_faq.html#matplotlib-pyplot-and-plt-how-are-they-related

import matplotlib.pyplot as plt
import datetime
import numpy as np
#from numpy import *
from pysolar.solar import *

date = datetime.datetime.now()

az = list()
el = list()
pp = list()
day=(2019, 12, 21)
day=(2019,  6, 21)
lat=49.5941335    # Adalbert-Stifter Str. 15, Uttenreuth
lon=11.0686023
t=range(24)
for hh in t:
  dat=datetime.datetime(day[0],day[1],day[2], hh, 00)
  el1=get_altitude(lat, lon, dat)
  az1=get_azimuth( lat, lon, dat)
  el.append(el1)
  az.append(az1)
  pp.append(radiation.get_radiation_direct(dat,el1))

plt.figure()
plt.plot( t, el,  'y-o')
plt.grid()
plt.title(f'Sun above Horizon {day[0]}-{day[1]}-{day[2]}')
plt.xlabel('t / h')
plt.ylabel('el / deg')

plt.figure()
plt.grid()
plt.plot( t, az,  '-o')   # az at noon time is 0/360
plt.title(f'Azimuth of Sun, {day[0]}-{day[1]}-{day[2]}')
plt.xlabel('t / h')
plt.ylabel('az / deg')

plt.figure()
plt.grid()
plt.plot( t, pp,  'r-o')     # solar power density
plt.title(f'Solar Irradiation {day[0]}-{day[1]}-{day[2]}')
plt.xlabel('t / h')
plt.ylabel('power density / W/m^2')

#plt.show()

data=np.array([np.array(t), np.array(az), np.array(el), np.array(pp)])
data.shape
from numpy import sin,cos,pi
a=np.array(az)*pi/180
e=np.array(el)*pi/180
# Normalenvektor der Einfallsrichtung from numpy import *
en = np.array([cos(a)*cos(e), sin(a)*cos(e), sin(e) ])

from mpl_toolkits import mplot3d
plt.figure()
ax = plt.axes(projection='3d')
ax.plot3D(en[0,:],en[1,:],en[2,:])
plt.show()


