#!/bin/ksh
#

# EXPORT list here
set -x
#export IOBUF_PARAMS=
ulimit -s unlimited
ulimit -a

#export MP_SHARED_MEMORY=yes
#export MEMORY_AFFINITY=core:2

#export NTHREADS_SIGCHGRS=2

#export FORECAST_SEGMENT=hr

#export memdir_template='$ROTDIR/enkf.$CDUMP.$PDY/$cyc'

set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $GEFS_ROCOTO/dev/versions/run_hera.ver

# Load modules
. /apps/lmod/lmod/init/ksh
module list
module purge

module use -a /scratch2/NCEPDEV/nwprod/NCEPLIBS/modulefiles

module load EnvVars/$EnvVars_ver
module load intel/$ips_ver
module load impi/$impi_ver
module load prod_util/$prod_util_ver
module load prod_envir/$prod_envir_ver
module load netcdf/$NetCDF_ver
module load hdf5/$HDF5_serial_ver

module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_FORECAST

