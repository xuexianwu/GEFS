#!/bin/ksh
#

# EXPORT list here
set -x
export IOBUF_PARAMS=


ulimit -s unlimited
ulimit -a

export MP_SHARED_MEMORY=yes
export MEMORY_AFFINITY=core:2

export NTHREADS_SIGCHGRS=2
export OMP_NUM_THREADS=1
export FORECAST_SEGMENT=hr

export memdir_template='$ROTDIR/enkf.$CDUMP.$PDY/$cyc'
. /usrx/local/prod/lmod/lmod/init/ksh
module purge
source $HOMEgfs/ush/load_fv3gfs_modules.sh exclusive
module list
export mem=`echo $RUNMEM|cut -c3-5`
# CALL executable job script here
$HOMEgfs/jobs/JGLOBAL_FORECAST

