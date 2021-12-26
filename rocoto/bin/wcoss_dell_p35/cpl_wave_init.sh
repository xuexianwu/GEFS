#!/bin/ksh -x

###############################################################
echo
echo "=============== START TO SOURCE FV3GFS WORKFLOW MODULES ==============="
. $GEFS_ROCOTO/bin/wcoss_dell_p35/common.sh

. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

export DATAROOT="$WORKDIR/tmpnwprd/gefs.$PDY/$cyc"
[[ ! -d $DATAROOT ]] && mkdir -p $DATAROOT
export DATA_DIR="$WORKDIR/com/gefs/dev"
###############################################################
echo
echo "=============== START TO RUN WAVE INIT ==============="
# Execute the JJOB
export RUNDIR="$WORKDIR/tmpnwprd" ##/gpfs/dell6/ptmp/Bing.Fu/o/p7ep2/tmpnwprd
export CDATE=${PDY}00
export CDUMP="gfs"
$HOMEgfs/jobs/JGLOBAL_WAVE_INIT
status=$?
exit $status

