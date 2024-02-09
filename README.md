# EKI_OBS

Calibrate AD99 tropical gravity wave parameters (`cw_tropics`, `Bt_eq`) in MiMA to observations of the QBO (`period`, `amplitude`) using Ensemble Kalman Inversion (EKI). 


## Dependencies
This code uses both julia and python.
* For ensemble Kalman inversion (EKI), we use the `EnsembleKalmanProcesses.jl` package, developed by Clima. See https://github.com/CliMA/EnsembleKalmanProcesses.jl for details on how to install and use this library. The docs page includes some examples, which this code is based on.
* The model we calibrate is Model of an Idealized Atmosphere (MiMA), so this code heavily relies on being able to run this model: at each iteration, we run MiMA with new parameter values. MiMA is available at https://github.com/mjucker/MiMA.  

## Problem Set up
We use this code to calibrate parameters in the gravity wave scheme, Alexander and Dunkerton (1999), within the climate model MiMA. 

### Parameters
* `cw_tropics` (m/s): Half-width of phase speeds in tropics   
* `Bt_eq` (Pa): Gravity wave stress at the equator   

### Outputs
* `period` (months): period of the Quasi-Biennial Oscillation (QBO) at 10 hPa, estimated using transition times from Easterly phase to Westerly phase.   
* `amplitude` (m/s): amplitude of the QBO, estimated using the amplitude of the wave.   


MiMA estimates of period, amplitude are calculated from 20 years of simulation. Observations are estimated from the Freie Universitat Berlin radiosonde data (https://www.geo.fu-berlin.de/en/met/ag/strat/produkte/qbo/index.html).

## Directory structure

Main bash scripts for running EKI are in this directory.
* `py_qbo_metrics/` contains methods used to calculate QBO period and amplitude for both observations and MiMA output.  
* `ground_truth_data/` contains raw QBO data and estimated QBO period and amplitude, used as "ground truth" in this analysis.  
* `juptyer_notebooks/` contains a few example notebooks for plotting/analysis.

## Important files
### Code
* `eki_update_step.jl` carries out ensemble Kalman inversion using the `EnsembleKalmanProcesses.jl` package. It reads in the current estimates of the outputs and the parameters and uses this to provide better estimates for the parameters at the next step. This code is largely based off the examples provided in the `EnsembleKalmanProcesses.jl` docs. 
* `py_qbo_metrics/get_QBO_TT_metrics.py` contains a python function that takes as inputs, the QBO winds (zonal mean zonal winds between 5degS and 5degN), and returns the estimates QBO periods and amplitudes across this dataset. We use the transition time approach to estimating a single QBO cycle.
* `py_qbo_metrics/mima_QBO_metrics.py` calculates QBO metrics from output from MiMA. This involves selecting zonal mean zonal winds and calling `py_qbo_metrics/get_QBO_TT_metrics.py`.
* `py_qbo_metrics/ground_truth_QBO_metrics.py` calculates QBO metrics from the ground truth radiosonde data. 

### Scripts
* `eki_calibration.sbatch` shows the loop through each step and is described below.
* `single_mima_run.sbatch` is a script for running one ensemble MiMA member. Parts of this script may be machine-specific so this will need to be edited (directories, libraries, and so on).
* `single_qbo_metrics.sbatch` is a script for estimating QBO metrics for one ensemble MiMA member - calls `py_qbo_metrics/mima_QBO_metrics.py`
* `script_eki_update_step.sbatch` is a script for calculating new parameter estimates using EKI - calls `eki_update_step.jl`


## Workflow

`eki_calibration.sbatch` is the main script that contains all EKI iterations. 

For ensemble size of `N`, for `n_its` iterations:

1. Run MiMA ensemble of size N, labelled from 0-(N-1):
* If this is iteration 0, run script `single_mima_run_iteration0_cold.sbatch` to start MiMA from cold for 40 years of simulations to reach warm state. (First 20 years will be discarded).  Input parameters are drawn with a Latin Hypercube Sampler from a uniform distribution, created by Rob King. These must be saved in `iteration_0/` directory as `paramlist.csv`.
* Else, run script `single_mima_run.sbatch` to start MiMA from a warm start, only run 22 years of simulations (First 2 years will be discarded). Then, this uses input parameters in `iteration_${i}/paramlist.csv`

2. `single_qbo_metrics.sbatch` calculates QBO metrics (period, amplitude) for each ensemble member from the last 20 years of simulations. This runs `py_qbo_metrics/mima_QBO_metrics.py`.

3. `script_eki_update_step.sbatch` carries out EKI update (using `eki_update_step.jl`) and saves these as `paramlist.csv` in directory for `iteration_${i+1}/`



## Authors
Please contact me with any questions: lauraman@stanford.edu


