mapdir=act16
outdir=actpost
maskfile=act_all_mask.fits
fwhm=${3}
lmin=${4}
lmax=2500
beam=${5}
lxcut=${6}
lycut=${7}
overwrite=${8}

#
./FSmooth -map ${mapdir}/${1}_I.fits -out ${outdir}/${2}_${fwhm}a_l${lmin}-${lmax}_I.fsm  -beam ${mapdir}/${beam} -fwhm ${fwhm} -lmin ${lmin} -lmax ${lmax} -mask ${mapdir}/${maskfile} -field I -lxcut ${lxcut} -lycut ${lycut} -overwrite ${overwrite}
./FSmooth -map ${mapdir}/${1}_Q.fits -out ${outdir}/${2}_${fwhm}a_l${lmin}-${lmax}_Q.fsm  -beam ${mapdir}/${beam} -fwhm ${fwhm} -lmin ${lmin} -lmax ${lmax}  -mask ${mapdir}/${maskfile} -field Q  -lxcut ${lxcut} -lycut ${lycut} -smoothmask act_matcoadd_standard_weight.fits  -overwrite ${overwrite}
./FSmooth -map ${mapdir}/${1}_U.fits -out ${outdir}/${2}_${fwhm}a_l${lmin}-${lmax}_U.fsm  -beam ${mapdir}/${beam} -fwhm ${fwhm} -lmin ${lmin} -lmax ${lmax}  -mask ${mapdir}/${maskfile} -field U  -lxcut ${lxcut} -lycut ${lycut}  -overwrite ${overwrite}
./FMerge  -map1 ${outdir}/${2}_${fwhm}a_l${lmin}-${lmax}_Q.fsm -map2 ${outdir}/${2}_${fwhm}a_l${lmin}-${lmax}_U.fsm -out ${outdir}/${2}_${fwhm}a_l${lmin}-${lmax}_QU.fsm  -overwrite ${overwrite}
./FQU2EB  ${outdir}/${2}_${fwhm}a_l${lmin}-${lmax}_QU.fsm  ${outdir}/${2}_${fwhm}a_l${lmin}-${lmax}  ${overwrite}