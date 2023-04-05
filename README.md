# EKI_OBS

Calibrate AD99 tropical gravity wave parameters (`cw_tropics`, `Bt_eq`) in MiMA to observations of the QBO (`period`, `amplitude`) using Ensemble Kalman Inversion. 

### Parameters
`cw_tropics` (m/s): Half-width of phase speeds in tropics   
`Bt_eq` (Pa): Gravity wave stress at the equator   

### Outputs
`period` (months): period of the Quasi-Biennial Oscillation (QBO) at 10 hPa, estimated using transition times from Easterly phase to Westerly phase.   
`amplitude` (m/s): amplitude of the QBO, estimated using the amplitude of the wave.   

MiMA estimates of period, amplitude are calculated from 20 years of simulation. Observations are estimated from the Freie Universitat Berlin radiosonde data (https://www.geo.fu-berlin.de/en/met/ag/strat/produkte/qbo/index.html).

### Directory structure

Main bash scripts for running EKI are in this directory.
`juptyer_notebooks/` contains plotting and analysis directories.  
`py_qbo_metrics/` contains methods used to calculate QBO period and amplitude for both observations and MiMA output.  
`ground_truth_data/` contains raw QBO data and estimated QBO period and amplitude, used as "ground truth" in this analysis.  

### How it works
`eki_calibration.sbatch` is the main script that contains all EKI iterations. 
For ensemble size of `N`, for `n_its` iterations:
1. Run MiMA ensemble of size N, labelled from 0-(N-1):
  If this is iteration 0, run script `single_mima_run_iteration0_cold.sbatch` to start MiMA from cold for 40 years of simulations to reach warm state. (First 20 years will be discarded).  Input parameters are drawn with a Latin Hypercube Sampler from a uniform distribution, created by Rob King. These must be saved in `iteration_0/` directory as `paramlist.csv`
  Else run script `single_mima_run.sbatch` to start MiMA from a warm start, only run 22 years of simulations (First 2 years will be discarded). Uses input parameters in `iteration_${i}/paramlist.csv`
  
2. `single_qbo_metrics.sbatch` calculates QBO metrics (period, amplitude) for each ensemble member from the last 20 years of simulations. This runs `py_qbo_metrics/mima_QBO_metrics.py`.

3. `script_eki_update_step.sbatch` carries out EKI update (using `eki_update_step.jl`) and saves these as `paramlist.csv` in directory for `iteration_${i+1}/`






