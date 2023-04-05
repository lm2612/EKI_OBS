# Script saves QBO metrics for ground truth
import os
import csv
import argparse

import numpy as np

from get_QBO_TT_metrics import get_QBO_periods_amplitudes
from mean_lat_weighted import mean_lat_weighted



basedir = f"../ground_truth_data/"
raw_data = f"{basedir}QBO_rawdata.csv"

try:
    # Read csv
    print(f"Reading file {raw_data}")
    timeseries = []
    with open(raw_data, mode='r') as csv_file:
        csv_reader = csv.reader(csv_file)
        line_count = 0
        for row in csv_reader:
            if line_count == 8:
                print(row)
            elif line_count >= 45:
                # select 10 hPa winds only, in row 14
                timeseries.append(float(row[14]))
            line_count += 1

except IOError as e:
    print(e)
    exit()

# rescale winds into m/s (currently in 10m/s)
u_mean10 = np.array(timeseries) * 0.1

# Get QBO periods and amplitudes. Data is in months, smoothing scale is 5 months 
periods, amplitudes = get_QBO_periods_amplitudes(u_mean10, N_smooth=5, points_per_month=1)
print(periods, amplitudes)

# Get means
period_mean = np.mean(periods)
amplitude_mean = np.mean(amplitudes)

# Get covariances in case we need them later
cov = np.cov(periods, amplitudes)
N = float(len(periods))
cov = cov/N
print(np.std(periods)/np.sqrt(N), np.std(amplitudes)/np.sqrt(N))
headers = ["run_id", "period", "amplitude", "cov_00", "cov_01", "cov_10", "cov_11"]
savearr = np.array(["truth", period_mean, amplitude_mean, cov[0,0], cov[0,1], cov[1,0], cov[1,1]])
print(savearr)

# Save to file
savefile = basedir+'QBO_TT_metrics_ground_truth.csv'

with open(savefile,'w') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    writer.writerow(savearr)

print("Saved as {}".format(savefile))
