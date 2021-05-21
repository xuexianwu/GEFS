#!/bin/bash
##!/bin/ksh -x
##!/bin/bash

set -x
ulimit -s unlimited
ulimit -a

# module_ver.h
. $SOURCEDIR/versions/gefs_wcoss_dell_p35.ver

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

module load lsf/$lsf_ver

module load CFP/$CFP_ver
export USE_CFP=YES

module list

# For Development
. $GEFS_ROCOTO/bin/wcoss_dell_p35/common.sh

# Export List

###############################################################
#echo
#echo "=============== START TO SOURCE FV3GFS WORKFLOW MODULES ==============="
#. $HOMEgfs/ush/load_fv3gfs_modules.sh
#status=$?
#[[ $status -ne 0 ]] && exit $status

#mem=`echo $RUNMEM|cut -c3-5`
#export DATAROOT="$WORKDIR/tmpnwprd/gefs.${PDY}/$cyc"
#export COMIN="$WORKDIR/com/gens/dev/gefs.${PDY}/$cyc/$mem/gfswave.${PDY}/$cyc"
#export COMOUT=$COMIN

[[ ! -d $DATAROOT ]] && mkdir -p $DATAROOT

###############################################################
echo
echo "=============== START TO RUN WAVE PREP ==============="
# Execute the JJOB
$HOMEgfs/jobs/JGLOBAL_WAVE_PREP
status=$?
exit $status

###############################################################
# Force Exit out cleanly
if [ ${KEEPDATA:-"NO"} = "NO" ] ; then rm -rf $DATAROOT ; fi
exit 0
