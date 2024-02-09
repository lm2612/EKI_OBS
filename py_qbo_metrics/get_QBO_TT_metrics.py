# Function to return QBO period using Transition Time method
import numpy as np
from scipy.interpolate import InterpolatedUnivariateSpline 

def get_QBO_periods_amplitudes(u_zonal, N_smooth=5, points_per_month=1):
    """ Function that returns all QBO periods and amplitudes (mean and the covariance matrices)
    using Transition Time (TT) method described in Schenzinger et al 2017
    Inputs: u_zonal (np array) zonal mean zonal wind at given height level, recommended 10hPa (MiMA index 13) 
            N_smooth (int) number of timesteps over which smoothing occurs. Should be 5 months. If monthly data
                    is provided (e.g. observed radiosonde data from Freie Uni. Berlin) N=5. 
                    If daily data is provided (e.g. output from MiMA) N_smooth=5*30=600
    Outputs: period (np array) all periods occuring in the time series. Note this will be returned same units
                    as data monthly or daily
             amplitude (np array) all amplitudes in m/s occuring in the time series
             """
    # First we smooth with a 5 month binomial smoothing
    u_smoothed = np.convolve(u_zonal, np.ones(N_smooth), mode='same')/N_smooth

    # Identify zero wind transitions, i.e. find roots
    interp = InterpolatedUnivariateSpline(np.arange(len(u_smoothed)),u_smoothed ) #,k=3)
    roots = interp.roots()

    transitions = np.round(roots).astype(int)
    print(transitions)
    amplitudes = []
    for start, stop in zip(transitions[::2], transitions[2::2]):
        period_max = np.max(u_smoothed[start:stop])
        period_min = np.min(u_smoothed[start:stop])
        amplitudes.append((period_max - period_min) / 2)
    periods = np.array(roots[2::2] - roots[:-2:2])

    return periods, amplitudes

