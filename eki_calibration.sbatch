#!/bin/bash

#SBATCH --job-name=ekp_cal   # job name
#SBATCH --partition=serc     # partition
#SBATCH --time=1:00:00       # walltime
#SBATCH --ntasks=1           # number of processor cores (i.e. tasks)
#SBATCH --nodes=1            # number of nodes
#SBATCH --mem-per-cpu=6G     # memory per CPU core
#SBATCH --output=/scratch/users/lauraman/MiMA/ekp_jobs/%j.out
#SBATCH --error=/scratch/users/lauraman/MiMA/ekp_jobs/%j.err

# Fixed run parameters, do not edit
N=50                        # Ensemble size
n_max=$((${N}-1))           # run number goes from 0 to N-1
it_first=0                  # first iteration is always 0

# Number of iterations and where to start, edit:
it_start=1        # start from 0 (cold start), unless this is a restart after failure
n_it=3            # Number of iterations
n_sims=8          # Max number of simulations running in paralel, either 8-10 on 32 cores, or 16-20 on 16 cores


export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:=1}
export JULIA_MPI_BINARY=system
export JULIA_CUDA_USE_BINARYBUILDER=false
# Loop over each EK iteration, starting from 1
for it in $(seq ${it_start} 1 ${n_it})
do
    if [ "$it" = "$it_start" ]; then
        if [ "$it" = "$it_first" ]; then
            # start from Rob's output (iteration 0), calculate QBO metrics and parameters first, then do first run
            #id_ens_py_array=$(sbatch --parsable --array=00-${n_max} single_qbo_metrics.sbatch $it)
            #id_ek_upd=$(sbatch --parsable --kill-on-invalid-dep=yes --dependency=afterok:$id_ens_py_array script_eki_update_step.sbatch $it)
            #id_ens_array=$(sbatch --parsable --kill-on-invalid-dep=yes --dependency=afterok:$id_ek_upd --array=00-${n_max}%${n_sims} single_mima_run.sbatch $it)
            echo "Running first iteration from cold"
            id_ens_array=$(sbatch --parsable --array=00-${n_max}%${n_sims} single_mima_run_iteration0_cold.sbatch $it $N)
        else 
            # start with the run for iteration $it
            echo "Running with restart"
            id_ens_array=$(sbatch --parsable --array=00-${n_max}%${n_sims} single_mima_run.sbatch $it $N)
        fi
    else
        # Restart from last output of previous iteration
        id_ens_array=$(sbatch --parsable --kill-on-invalid-dep=yes --dependency=afterok:$id_ek_upd --array=00-${n_max}%${n_sims} single_mima_run.sbatch $it $N)
    fi
    # Run python script to get QBO metrics for each of our simulations
    id_ens_py_array=$(sbatch --parsable --kill-on-invalid-dep=yes --dependency=afterok:$id_ens_array --array=00-${n_max} single_qbo_metrics.sbatch $it $N)
    # Do EKI update 
    id_ek_upd=$(sbatch --parsable --kill-on-invalid-dep=yes --dependency=afterok:$id_ens_py_array script_eki_update_step.sbatch $it $N)
done

