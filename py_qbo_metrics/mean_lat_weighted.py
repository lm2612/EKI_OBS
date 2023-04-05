#### Script containing useful functions relevant to climate model data
import numpy as np

def mean_lat_weighted(variable, lats, axis=(0)):
    """Area weighted mean, where weighting is proportional to the cosine of latitude"""
    return np.average(variable, weights=np.cos(lats*np.pi/180.), axis=axis)

