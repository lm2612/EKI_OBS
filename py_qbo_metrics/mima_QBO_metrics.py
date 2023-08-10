# Script saves QBO metrics for EKI
import os
import csv
import argparse

import numpy as np
import netCDF4 as nc


from get_QBO_TT_metrics import get_QBO_periods_amplitudes
from mean_lat_weighted import mean_lat_weighted


# Get run directory from argparser
parser = argparse.ArgumentParser(
                    description='Save QBO metrics for simulation, indexed by iteration number and run number')
# 3 arguments: iteration, run_num and ensemble size
parser.add_argument('iteration', metavar='it', type=int, nargs='+',
                     help='iteration of EKI')
parser.add_argument('run_number', metavar='run_num', type=int, nargs='+',
                     help='run number refering to ensemble member ')
parser.add_argument('ensemble_size', metavar='N', type=int, nargs='+',
                     help='total number of ensemble members')

args = parser.parse_args()
iteration = args.iteration[0]
run_num = args.run_number[0]
N = args.ensemble_size[0]

basedir = os.environ['GROUP_SCRATCH']+f"/EKI_N{N}/iteration_{iteration}/"
#rundir = basedir + f"{run_num:02d}/"
rundir = basedir + f"{run_num}/"


print("Reading atmos_daily_*.nc files from ", rundir)

# We need to concatenate years 0-20 (previously 20-40)
# Get first run
filename = 'atmos_daily_0'
try:
    dataset = nc.Dataset(rundir+filename+'.nc', 'r')
except IOError as e:
    print(e)
    exit()

time = dataset['time']
pfull = dataset['pfull']
ucomp = dataset['ucomp']
lat = dataset['lat']

# Calc the zonal mean zonal winds at 10 hPa between 5 deg S and 5 deg N
u_mean10 = mean_lat_weighted( ucomp[:, 13, 30:34, :].mean(axis=(-1)), lat[30:34], axis=(-1) )

for i in range(1, 21):
    filename = f"atmos_daily_{i}"
    try:
        dataset = nc.Dataset(rundir+filename+'.nc', 'r')
    except IOError as e:
        print(e)
        exit()

    time = dataset['time']
    ucomp = dataset['ucomp']

    # Calc the zonal mean zonal winds at 10 hPa between 5 deg S and 5 deg N
    u_mean10_new = mean_lat_weighted( ucomp[:, 13, 30:34, :].mean(axis=(-1)), lat[30:34], axis=(-1) )

    # Concatenate 
    u_mean10 = np.concatenate((u_mean10, u_mean10_new), axis=0)

# Get QBO periods and amplitudes. Daily data so the smoothing scale is 30 * 5 months  = 150 days
periods, amplitudes = get_QBO_periods_amplitudes(u_mean10, N_smooth=150, points_per_month=30)
# period is returned in units of days
periods = periods / 30.
print(periods, amplitudes)

# Get means
period_mean = np.mean(periods)
amplitude_mean = np.mean(amplitudes)

# Get covariances in case we need them later
cov = np.cov(periods, amplitudes)

N = len(periods)
period_sem = np.std(periods)/np.sqrt(N)
amplitude_sem = np.std(amplitudes)/np.sqrt(N)
print(np.std(periods)/np.sqrt(N), np.std(amplitudes)/np.sqrt(N))

headers = ["run_id", "period", "amplitude", "cov_00", "cov_01", "cov_10", "cov_11", "n", "period_sem", "amplitude_sem"]
savearr = np.array([run_num, period_mean, amplitude_mean, cov[0,0], cov[0,1], cov[1,0], cov[1,1], N, period_sem, amplitude_sem])
print(savearr)

# Save to file
savefile = rundir+'QBO_TT_metrics.csv'

with open(savefile,'w') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    writer.writerow(savearr)

print("Saved as {}".format(savefile))
