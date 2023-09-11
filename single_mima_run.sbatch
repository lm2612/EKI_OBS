#!/bin/bash
#SBATCH --nodes=1             # number of nodes
#SBATCH --ntasks=16
#SBATCH --time=48:00:00
#SBATCH --mem=16G
###SBATCH --constraint=CPU_GEN:RME
#SBATCH --constraint="[CLASS:SH3_CBASE|CLASS:SH3_CPERF]"
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

cwd=`pwd`

#--------------------------------------------------------------------------------------------------------
# Set up run directory
PLATFORM=SH03_CEES
executable=${GROUP_HOME}/${USER}/MiMA/build/mima.x
rundir=${GROUP_SCRATCH}/EKI_N${N}/iteration_${iteration_eki}/${run_num}/

previous_iteration_eki=$((iteration_eki-1))

# Set up restart files and basic input files from control run (run033)
# which has input params cwtropics = 35,  cw = 35, Bt_0  = 0.0043,  Bt_nh = 0.0035
input=${SCRATCH}/EKI/inputs/            # contains diag_table, field_table, input.nml and $INPUT/. Namelist is set up for 360 days
restartdir=${GROUP_SCRATCH}/EKI_N${N}/iteration_${previous_iteration_eki}/${run_num}/     # restart from end of prev run 

echo "restarting from previous iteration ${previous_iteration_eki}. Directory ${restartdir}"

# Make run dir
[ ! -d $rundir ] && mkdir $rundir
# Copy executable to rundir
cp $executable $rundir/
# Copy input to rundir
cp -r $input/* $rundir/
# Copy restart files
[ ! -d $rundir/RESTART/ ] && mkdir $rundir/RESTART/
cp -r $restartdir/RESTART/*res* $rundir/RESTART/
cp -r $restartdir/RESTART/*res* $rundir/INPUT/

previous_iteration_eki=$((iteration_eki-1))

# Edit input namelist for this iteration's parameters
# Read entry from version file where version=mima_param_defs_XXXX
mima_param_file="${GROUP_SCRATCH}/EKI_N${N}/iteration_${iteration_eki}/paramlist.csv"

while IFS=, read -r runid cw Bt;
do
    ## Get when runid = run_num
    if [[ $runid == $run_num ]];
    then 
        echo "Found runid $runid. Editing input.nml to include cwtropics = $cw, Bt_eq = $Bt"
        # Change corresponding parameter in namelist using sed to find base value and replace
        sed -i "s/cwtropics = 35.0/cwtropics = $cw/g" $rundir/input.nml	
        sed -i "s/Bt_eq = 0.0043/Bt_eq = $Bt/g" $rundir/input.nml 
    fi

done < "$mima_param_file"

#--------------------------------------------------------------------------------------------------------
echo "**** SET UP COMPLETE ****"

# Run the model
cd $rundir
echo "******* RUN MIMA *******" 

N_PROCS=16
PLATFORM=SH03_CEES
CCOMB=${GROUP_HOME}/${USER}/MiMA/build/mppnccombine
NYEAR=20

for ((i=-1;i<=$NYEAR;i++))
do 
    echo "Running year $i ..."
    srun --ntasks $N_PROCS --mem 16G mima.x
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

