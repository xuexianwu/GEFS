#!/bin/bash

set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $GEFS_ROCOTO/dev/versions/gefs_wcoss_dell_p35.ver

# Load modules
. /usrx/local/prod/lmod/lmod/init/ksh
module list
module purge

module load EnvVars/$EnvVars_ver
module load ips/$ips_ver
module load impi/$impi_ver
module load prod_util/$prod_util_ver
module load prod_envir/$prod_envir_ver

#module load NetCDF/4.5.0
module load HDF5-parallel/$HDF5_parallel_ver
module load NetCDF-parallel/$NetCDF_parallel_ver

module load lsf/$lsf_ver

module load CFP/$CFP_ver
export USE_CFP=YES

module list

# For Development
. $GEFS_ROCOTO/bin/wcoss_dell_p35/common.sh

# Export List
(( OMP_NUM_THREADS_CH = 40 / GEFS_PPN ))
export OMP_NUM_THREADS_CH
export COMIN=${COMIN:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc/atmos}
export COMOUT=${COMOUT:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc/atmos}
export GESOUT=${GESOUT:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc/nwges}

$SOURCEDIR/jobs/JGEFS_ATMOS_PREP