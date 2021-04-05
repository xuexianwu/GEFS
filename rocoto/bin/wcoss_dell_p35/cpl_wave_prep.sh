#!/bin/ksh -x

###############################################################
echo
echo "=============== START TO SOURCE FV3GFS WORKFLOW MODULES ==============="
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

mem=`echo $RUNMEM|cut -c3-5`
export DATAROOT="$WORKDIR/tmpnwprd/gefs.${PDY}/$cyc"
export COMIN="$WORKDIR/com/gens/dev/gefs.${PDY}/$cyc/$mem/gfswave.${PDY}/$cyc"
export COMOUT=$COMIN

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
