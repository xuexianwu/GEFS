#!/bin/ksh
#

# EXPORT list here
set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $GEFS_ROCOTO/dev/versions/run_hera.ver

# Load modules
. /apps/lmod/lmod/init/ksh
module list
module purge

module load intel/$ips_ver
module load grib_util/$grib_util_ver
module load prod_util/$prod_util_ver
#module load prod_envir/$prod_envir_ver
module load netcdf/$NetCDF_ver

module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

#export OMP_NUM_THREADS=6

# export for development runs only begin

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_GETCFSSST

