#!/bin/ksh
#

set -x
# export IOBUF_PARAMS=cfi*:size=64M:count=4:verbose
# export FORT_BUFFERED=TRUE
# export MKL_CBWR=AVX
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
#module load prod_envir/$prod_envir_ver

module load NCO/$NCO_ver
#module load python/$python_ver
module use -a /contrib/anaconda/modulefiles
module load anaconda/latest

module load hdf5_parallel/$HDF5_parallel_ver
module load netcdf_parallel/$NetCDF_parallel_ver

module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_CHEM_INIT
