#!/bin/bash

#SBATCH --time=2:00:00        # walltime
#SBATCH --ntasks=1           # number of processor cores (i.e. tasks)
#SBATCH --mem-per-cpu=4G      # memory per CPU core
#SBATCH --job-name=qbo_metrics   # job name
#SBATCH --partition=serc      # partition
#SBATCH --output=/scratch/users/lauraman/MiMA/ekp_jobs/qbo_metrics_%j_%a.out
#SBATCH --error=/scratch/users/lauraman/MiMA/ekp_jobs/qbo_metrics_%j_%a.err

# Set up conda env
. $GROUP_HOME/lauraman/miniconda3/etc/profile.d/conda.sh
conda activate EKI_env

python --version

# Get run directory
iteration_eki=${1?Error: no iteration given}
N=${2?Error: no N given}

# Get version info by reading line run_num 
run_num=${SLURM_ARRAY_TASK_ID}
echo "${run_num}"

cd py_qbo_metrics/ 
python mima_QBO_metrics.py $iteration_eki $run_num $N

