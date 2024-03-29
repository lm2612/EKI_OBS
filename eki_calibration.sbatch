#!/bin/bash

#SBATCH --job-name=ekp_cal   # job name
#SBATCH --partition=serc     # partition
#SBATCH --time=1:00:00       # walltime
#SBATCH --ntasks=1           # number of processor cores (i.e. tasks)
#SBATCH --nodes=1            # number of nodes
#SBATCH --mem-per-cpu=6G     # memory per CPU core
#SBATCH --output=/scratch/users/lauraman/MiMA/ekp_jobs/%j.out
#SBATCH --error=/scratch/users/lauraman/MiMA/ekp_jobs/%j.err

it=${1?Error: no EKI iteration given}
N=${2?Error: no N given}
echo "Submitting all jobs for N=$N for iteration $it"

# Fixed run parameters, do not edit
n_max=$((${N}-1))           # run number goes from 0 to N-1
it_first=1                  # first iteration is always 1

# Number of iterations and where to start, edit:
n_sims=18         # Max number of simulations running in paralel, either 8-10 on 32 cores, or 16-20 on 16 cores


export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:=1}
export JULIA_MPI_BINARY=system
export JULIA_CUDA_USE_BINARYBUILDER=false


if [ "$it" = "$it_first" ]; then
    echo "First need to calculate param list from Rob's simulations"
    id_ek_upd=$(sbatch --parsable script_eki_update_step.sbatch 0 $N)
    id_ens_array=$(sbatch --parsable --kill-on-invalid-dep=yes --dependency=afterok:$id_ek_upd --array=00-${n_max}%${n_sims} single_mima_run.sbatch $it $N)
else 
    # start with the run for iteration $it
    id_ens_array=$(sbatch --parsable --array=00-${n_max}%${n_sims} single_mima_run.sbatch $it $N)
fi
# Run python script to get QBO metrics for each of our simulations
id_ens_py_array=$(sbatch --parsable --kill-on-invalid-dep=yes --dependency=afterok:$id_ens_array --array=00-${n_max} single_qbo_metrics.sbatch $it $N)
# Do EKI update 
id_ek_upd=$(sbatch --parsable --kill-on-invalid-dep=yes --dependency=afterok:$id_ens_py_array script_eki_update_step.sbatch $it $N)

# submit this job again with it = it + 1
it_next=$(($it+1))
id_next_cal=$(sbatch --kill-on-invalid-dep=yes --dependency=afterok:$id_ek_upd eki_calibration.sbatch $it_next $N)
    
