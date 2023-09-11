#!/bin/bash
#SBATCH --nodes=1             # number of nodes
#SBATCH --tasks-per-node=32
#SBATCH --time=48:00:00
#SBATCH --mem-per-cpu=4G
#SBATCH --constraint=CPU_GEN:RME
####SBATCH --constraint="[CLASS:SH3_CBASE|CLASS:SH3_CPERF]"
#SBATCH --job-name=mima_run   # job name
#SBATCH --partition=serc      # partition
#SBATCH --output=/scratch/users/lauraman/MiMA/ekp_jobs/run_%j_%a.out
#SBATCH --error=/scratch/users/lauraman/MiMA/ekp_jobs/run_%j_%a.err

echo "*** NODE INFO ***"
echo $SLURM_NODELIST
#scontrol show job -d $SLURM_JOBID

echo "**************"

iteration_eki=${1?Error: no EKI iteration given}
N=${2?Error: no N given}

# Get version info by reading line run_num 
run_num=${SLURM_ARRAY_TASK_ID}
echo "${run_num}"

# RUN MiMA SIMULATION
#--------------------------------------------------------------------------------------------------------
# Set up relevant paths and modules
echo "**** SETUP ****"
ulimit -s unlimited

module load ifort
module load icc
module load netcdf-fortran
module load netcdf-c

module list
cwd=`pwd`

# Currently two libraries are not found in linking on SH03_CEES: libfabric and hwloc. Manually add them here.
export LIBFABRIC_PATH="/home/groups/s-ees/share/cees/spack_cees/spack/opt/spack/linux-centos7-zen2/intel-2021.4.0/libfabric-1.13.1-fcah2ztj7a4kigbly6vxqa7vuwesyxmr/lib/"
export HWLOC_PATH="/home/groups/s-ees/share/cees/spack_cees/spack/opt/spack/linux-centos7-zen2/intel-2021.4.0/hwloc-2.5.0-4yz4g5jbydc4euoqrbudraxssx2tcaco/lib/"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${LIBFABRIC_PATH}:${HWLOC_PATH}"

#--------------------------------------------------------------------------------------------------------
# Set up run directory
PLATFORM=SH03_CEES
executable=${GROUP_HOME}/${USER}/MiMA/build/mima.x
rundir=${GROUP_SCRATCH}/EKI_N${N}/iteration_${iteration_eki}/${run_num}/

## Run dir must already exist
# Get most recent filename
most_recent_file=$(ls -t $rundir/atmos_daily_*.nc | head -n 1)
# Get restart number
atmos_daily_fname=$(basename -s .nc ${most_recent_file})
restart_number=$(cut -d'_' -f3 <<< ${atmos_daily_fname})

echo "Starting from $restart_number"
restartdir=${rundir}/restart_history/restart_${restart_number}/
# Copy restart files
cp -r $restartdir/*res* $rundir/RESTART/
cp -r $restartdir/*res* $rundir/INPUT/

run_number=$((restart_number+1))

#--------------------------------------------------------------------------------------------------------
echo "**** SET UP COMPLETE ****"

# Run the model
cd $rundir
# remove old files
rm atmos_*.nc.0*


echo "******* RUN MIMA *******" 
echo "******* RESTARTING FROM $run_number *******"

N_PROCS=32
PLATFORM=SH03_CEES
CCOMB=${GROUP_HOME}/${USER}/MiMA/build/mppnccombine
NYEAR=20

for ((i=$run_number;i<=$NYEAR;i++))
do 
    echo "Running year $i ..."
    srun --ntasks $N_PROCS mima.x
    echo "Done year $i, now postprocessing... "
    $CCOMB -r atmos_daily_${i}.nc atmos_daily.nc.????
    #$CCOMB -r atmos_avg_${i}.nc atmos_avg.nc.????
    #$CCOMB -r atmos_davg_${i}.nc atmos_davg.nc.????
    #$CCOMB -r atmos_dext_${i}.nc atmos_dext.nc.????
    cp RESTART/*res* INPUT/
    [ ! -d restart_history/restart_$i ] && mkdir -p restart_history/restart_$i
    cp -r RESTART/*res* restart_history/restart_$i/
    echo "Done postproc $i"
done

echo "******* RUN COMPLETE FOR ALL YEARS 1 to $NYEAR *****"
echo "done"

