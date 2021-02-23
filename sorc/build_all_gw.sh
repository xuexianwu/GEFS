#!/bin/ksh
set -ex

#--make symbolic links for EMC installation and hardcopies for NCO delivery

while getopts e:m: option
do
    case "${option}"
    in
        e) RUN_ENVIR=${OPTARG};;
        m) machine=${OPTARG};;

    esac

done

RUN_ENVIR=${RUN_ENVIR:-emc}
machine=${machine:-dell}

echo $RUN_ENVIR
echo $machine

LINK="ln -fs"
[[ $RUN_ENVIR = nco ]] && LINK="cp -rp"

pwd=$(pwd -P)

#------------------------------------
if [[ -d global-workflow.fd ]] ; then
    if [[ -L global-workflow.fd ]] ; then
        echo " ... You don't need to build global-workflow because global-workflow.fd was linked from other directiory!"
    else
        echo " .... Building global-workflow .... "
        #./build_global-workflow.sh > $logs_dir/build_global-workflow.log 2>&1
    fi
fi

#if [[ $RUN_ENVIR = nco ]]; then
    $LINK global-workflow.fd/sorc/build_gsd_prep_chem.sh .
    $LINK global-workflow.fd/sorc/gsd_prep_chem.fd .
#fi

exit $ERR
