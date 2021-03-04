#!/bin/bash

set -x
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

#module load CFP/$CFP_ver
#export USE_CFP=YES

module list

# For Development
. $GEFS_ROCOTO/bin/hera/common.sh

# Export List

# Set NCO messaging proxies
export jlogfile=/dev/null
export jobid=${job}.$$

$SOURCEDIR/jobs/JGEFS_WAVE_PREP
