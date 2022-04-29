#!/bin/ksh

# EXPORT list here
set -x
export IOBUF_PARAMS=cfi*:size=64M:count=4:verbose
ulimit -s unlimited
ulimit -a

# module_ver.h
. $SOURCEDIR/versions/gefs_hera.ver

# Load modules
. /apps/lmod/lmod/init/ksh
module list
module purge

module use -a /scratch2/NCEPDEV/nwprod/NCEPLIBS/modulefiles

module load EnvVars/$EnvVars_ver
module load intel/$ips_ver
module load impi/$impi_ver
module load prod_util/$prod_util_ver
#module load prod_envir/$prod_envir_ver
module load grib_util/$grib_util_ver
module load netcdf/$NetCDF_ver
module load hdf5/$HDF5_serial_ver

#module load CFP/$CFP_ver
#export USE_CFP=YES

module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List

#export OMP_NUM_THREADS=4

#export OMP_NUM_THREADS=4

export MP_SHARED_MEMORY=no
export MEMORY_AFFINITY=core:4

#export NODES=$SLURM_JOB_NUM_NODES
#export total_tasks=$SLURM_NTASKS
#export OMP_NUM_THREADS=4
#export taskspernode=$SLURM_CPUS_ON_NODE

#export FORECAST_SEGMENT=hr

# export for development runs only begin

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_ENSSTAT

