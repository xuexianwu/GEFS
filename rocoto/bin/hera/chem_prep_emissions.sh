#!/bin/ksh
#

set -x
# export IOBUF_PARAMS=cfi*:size=64M:count=4:verbose
# export FORT_BUFFERED=TRUE
# export MKL_CBWR=AVX
ulimit -s unlimited
ulimit -a

# module_ver.h
. $SOURCEDIR/versions/gefs_hera.ver

# Load modules
. /apps/lmod/lmod/init/ksh
module list
module purge

module load EnvVars/$EnvVars_ver
module load intel/$ips_ver
#module load impi/$impi_ver
module load prod_util/$prod_util_ver
module load prod_envir/$prod_envir_ver
#module load grib_util/$grib_util_ver

module load netcdf/$NetCDF_ver
module load hdf5/$HDF5_serial_ver


module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_CHEM_PREP_EMISSIONS
