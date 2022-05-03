#!/bin/ksh

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
module load grib_util/$grib_util_ver
#module load NetCDF/$NetCDF_ver
#module load HDF5-serial/$HDF5_serial_ver

module load lsf/$lsf_ver

module load CFP/$CFP_ver
export USE_CFP=YES

module list

# For Development
. $GEFS_ROCOTO/bin/wcoss_dell_p35/common.sh

# Export List
#export RERUN=NO
export COMIN=${COMIN:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc}
export COMOUT=${COMOUT:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc}

#export COMIN=${COMIN:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc}
#export COMOUT=${COMOUT:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc}
#export COMINgfs=${COMINgfs:-$(compath.py gfs/prod/gfs.${PDY})/$cyc/atmos}
mem=$(echo $RUNMEM|cut -c3-5)
#export PBS_JOBID=$LSB_JOBID
export COMIN=${COMIN:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc/$mem/gfs.$PDY/$cyc}
export COMOUT=${COMOUT:-${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/$cyc}
export COMINgfs=${COMINgfs:-$(compath.py gfs/prod/gfs.${PDY})/$cyc/atmos}

# Copy ocndaily data
#cp ${COMOUT}/00/$mem/gfs.$PDY/00/*daily* $COMOUT/00/ocndaily/$mem
#cp ${COMROOT}/${NET}/${envir}/${RUN}.${PDY}/00/$mem/gfs.$PDY/00/*daily* $COMOUT/00/ocndaily/$mem
#cp ${COMOUT}/$mem/gfs.$PDY/00/*daily* $COMOUT/ocndaily/$mem
cp ${COMIN}/ocean/*daily* $COMOUT/ocndaily/$mem

# CALL executable job script here
$SOURCEDIR/jobs/JGEFS_ATMOS_PRDGEN
