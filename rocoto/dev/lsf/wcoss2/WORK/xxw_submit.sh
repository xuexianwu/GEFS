#!/bin/bash

# qdel `qselect -u $USER`

set -xa
export PS4='$SECONDS + $(basename $(basename ${0}))[$LINENO] '

npert=2 #30
  
memberlist="c00"
imem=1
while [[ imem -le $npert ]];
do
    memberlist="$memberlist p$(printf %02i $imem)"
    (( imem++ ))
done
echo $memberlist


export PBS_O_WORKDIR=`pwd`/tmp

getcfssst=$(qsub ../init/atmos/jgefs_atmos_getcfssst.ecf)
wave_init=$(qsub ../init/wave/jgefs_wave_init.ecf)

atmos_prep_dep=""
imem=1
for mem in $memberlist
do
	sed -e "s/c00/$mem/g" ../d0_16/atmos/jgefs_atmos_prep.ecf > jgefs_atmos_prep.ecf_$mem
  	atmos_prep[$imem]=$(qsub jgefs_atmos_prep.ecf_$mem)
	atmos_prep_dep="$atmos_prep_dep:${atmos_prep[$imem]}"
	(( imem++ ))
done


#atmos_init=$(qsub -W depend=afterok:${atmos_prep[1]}:${atmos_prep[2]}:${atmos_prep[3]} ../init/atmos/jgefs_atmos_init_recenter.ecf)
atmos_init=$(qsub -W depend=afterok${atmos_prep_dep} ../init/atmos/jgefs_atmos_init_recenter.ecf)

# -- wave_prep
wave_prep_dep=""
imem=1
for mem in $memberlist
do
 	sed -e "s/c00/$mem/g" ../d0_16/wave/jgefs_wave_prep.ecf > jgefs_wave_prep.ecf_$mem
 	wave_prep[$imem]=$(qsub -W depend=afterok:$wave_init jgefs_wave_prep.ecf_$mem)
	wave_prep_dep="$wave_prep_dep:${wave_prep[$imem]}"
	(( imem++ ))
done

# --- chem
chem_prep=$(qsub ../chem/jgefs_chem_prep_emissions.ecf)
chem_init=$(qsub -W depend=afterok:$chem_prep:$atmos_init ../chem/jgefs_chem_init.ecf)
chem_fcst=$(qsub -W depend=afterok:$chem_init:$getcfssst ../chem/jgefs_chem_forecast.ecf)
chem_post=$(qsub -W depend=after:$chem_fcst ../chem/jgefs_chem_post.ecf)
chem_prdgen=$(qsub -W depend=after:$chem_post ../chem/jgefs_chem_prdgen.ecf)


#------
atmos_prdgen_gfs=$(qsub ../post_processing/d0_16/atmos/jgefs_atmos_prdgen_gfs.ecf)

atmos_prdgen_dep=""
wave_post_dep=""
imem=1
for mem in $memberlist
do
    sed -e "s/c00/$mem/g" ../d0_16/jgefs_forecast.ecf > jgefs_forecast.ecf_$mem
	if [[ $imem == 1 ]]; then
		fcst[$imem]=$(qsub -W depend=afterok:$getcfssst:$atmos_init:${wave_prep[$imem]} jgefs_forecast.ecf_$mem)
	else
		fcst[$imem]=$(qsub -W depend=afterok:$getcfssst:$atmos_init:${wave_prep[$imem]}:${wave_prep[1]} jgefs_forecast.ecf_$mem)
	fi

    sed -e "s/c00/$mem/g" ../d0_16/atmos/jgefs_atmos_post.ecf > jgefs_atmos_post.ecf_$mem
    atmos_post[$imem]=$(qsub -W depend=after:${fcst[$imem]} jgefs_atmos_post.ecf_$mem)

    sed -e "s/c00/$mem/g" ../d0_16/atmos/jgefs_atmos_prdgen.ecf > jgefs_atmos_prdgen.ecf_$mem
    atmos_prdgen[$imem]=$(qsub -W depend=after:${atmos_post[$imem]} jgefs_atmos_prdgen.ecf_$mem)
	atmos_prdgen_dep="$atmos_prdgen_dep:${atmos_prdgen[$imem]}"

    sed -e "s/c00/$mem/g" ../d0_16/atmos/jgefs_atmos_postsnd.ecf > jgefs_atmos_postsnd.ecf_$mem
    atmos_postsnd[$imem]=$(qsub -W depend=after:${fcst[$imem]} jgefs_atmos_postsnd.ecf_$mem)

	sed -e "s/c00/$mem/g" ../d0_16/jgefs_fcst_post_manager.ecf > jgefs_fcst_post_manager.ecf_$mem
    fcst_post_manager[$imem]=$(qsub -W depend=after:${fcst[$imem]} jgefs_fcst_post_manager.ecf_$mem)
	# --- wave
    sed -e "s/c00/$mem/g" ../d0_16/wave/jgefs_wave_post.ecf > jgefs_wave_post.ecf_$mem
    wave_post[$imem]=$(qsub -W depend=after:${fcst[$imem]} jgefs_wave_post.ecf_$mem)
	wave_post_dep="$wave_post_dep:${wave_post[$imem]}"

    sed -e "s/c00/$mem/g" ../d0_16/wave/jgefs_wave_gempak.ecf > jgefs_wave_gempak.ecf_$mem
    wave_gempak[$imem]=$(qsub -W depend=after:${wave_post[$imem]} jgefs_wave_gempak.ecf_$mem)

	(( imem++ ))
done

atmos_ensstat=$(qsub -W depend=after${atmos_prdgen_dep} ../post_processing/d0_16/atmos/jgefs_atmos_ensstat.ecf)
atmos_enspost=$(qsub -W depend=afterok${atmos_prdgen_dep}:$atmos_prdgen_gfs ../post_processing/d0_16/atmos/jgefs_atmos_enspost.ecf)

atmos_ensavg_nemsio=$(qsub -W depend=after${atmos_prdgen_dep} ../post_processing/d0_16/atmos/jgefs_atmos_ensavg_nemsio.ecf)

atmos_avg_postsnd=$(qsub -W depend=after:$atmos_ensavg_nemsio ../post_processing/d0_16/atmos/jgefs_atmos_avg_postsnd.ecf)

atmos_gempak=$(qsub -W depend=after:${atmos_ensstat}${atmos_prdgen_dep} ../gempak/atmos/jgefs_atmos_gempak.ecf)
atmos_gempak_meta=$(qsub -W depend=afterok:$atmos_gempak ../gempak/atmos/jgefs_atmos_gempak_meta.ecf)
atmos_avgspr_gempak_meta=$(qsub -W depend=afterok:$atmos_gempak ../gempak/atmos/jgefs_atmos_avgspr_gempak_meta.ecf)

wave_stat=$(qsub -W depend=afterok$wave_post_dep ../post_processing/d0_16/wave/jgefs_wave_stat.ecf)


#--d
atmos_prdgen_lr_dep=""
imem=1
for mem in $memberlist
do
   	sed -e "s/c00/$mem/g" ../d16_35/atmos/jgefs_atmos_forecast.ecf > jgefs_atmoslr_forecast.ecf_$mem
  	atmos_fcst_lr[$imem]=$(qsub -W depend=afterok:${fcst[$imem]} jgefs_atmoslr_forecast.ecf_$mem)

   	sed -e "s/c00/$mem/g" ../d16_35/atmos/jgefs_atmos_post.ecf > jgefs_atmoslr_post.ecf_$mem
   	atmos_post_lr[$imem]=$(qsub -W depend=after:${atmos_fcst_lr[$imem]} jgefs_atmoslr_post.ecf_$mem)

   	sed -e "s/c00/$mem/g" ../d16_35/atmos/jgefs_atmos_prdgen.ecf > jgefs_atmoslr_prdgen.ecf_$mem
   	atmos_prdgen_lr[$imem]=$(qsub -W depend=after:${atmos_post_lr[$imem]} jgefs_atmoslr_prdgen.ecf_$mem)
	atmos_prdgen_lr_dep="$atmos_prdgen_lr_dep:${atmos_prdgen_lr[$imem]}"

	(( imem++ ))
done


atmos_ensstat_lr=$(qsub -W depend=after${atmos_prdgen_lr_dep} ../post_processing/d16_35/atmos/jgefs_atmos_ensstat.ecf)
atmos_ens_lr=$(qsub -W depend=afterok${atmos_prdgen_lr_dep} ../post_processing/d16_35/atmos/jgefs_atmos_enspost.ecf)
