#!/bin/bash

#SBATCH --time=1:00:00          # walltime
#SBATCH --ntasks=1              # number of processor cores (i.e. tasks)
#SBATCH --nodes=1               # number of nodes
#SBATCH --mem-per-cpu=6G        # memory per CPU core
#SBATCH --job-name=eki_update   # job name
#SBATCH --partition=serc        # partition
#SBATCH --output=/scratch/users/lauraman/MiMA/ekp_jobs/eki_update_step_%j.out
#SBATCH --error=/scratch/users/lauraman/MiMA/ekp_jobs/eki_update_step_%j.err

#module load julia/1.5.2 hdf5/1.10.1 netcdf-c/4.6.1 openmpi/4.0.1
module load julia/1.7.2 hdf5 netcdf openmpi

julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.API.precompile()'

iteration_=${1?Error: no iteration given}
N=${2?Error: ensemble size must be provided}

next_iteration=$((${iteration_}+1))
# Create directory for next iteration to save eki update parameters
next_eki_dir=${SCRATCH}/EKI_N${N}/iteration_${next_iteration}/
[ ! -d ${next_eki_dir} ] && mkdir ${next_eki_dir}

# do EKI update
julia --project eki_update_step.jl --iteration $iteration_ --N $N 
echo "Ensemble ${iteration_} recovery finished."

