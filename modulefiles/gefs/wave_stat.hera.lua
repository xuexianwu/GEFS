help([[
Load environment for building wave_stat on hera
]])

-- prepend_path("MODULEPATH", "/scratch2/NCEPDEV/nwprod/hpc-stack/libs/hpc-stack-gfsv16/modulefiles/stack")
prepend_path("MODULEPATH", "/scratch2/NCEPDEV/nwprod/NCEPLIBS/modulefiles")

EnvVars_ver=os.getenv("EnvVars_ver") or "1.0.2"
load(pathJoin("EnvVars", EnvVars_ver))

intel_ver=os.getenv("intel_ver") or "19.1.3.304"
load(pathJoin("intel", intel_ver))

impi_ver=os.getenv("impi_ver") or "2.7.10"
load(pathJoin("impi", impi_ver))


g2_ver=os.getenv("g2_ver") or "3.1.1"
load(pathJoin("g2", g2_ver))

w3nco_ver=os.getenv("w3nco_ver") or "2.0.7"
load(pathJoin("w3nco", w3nco_ver))

bacio_ver=os.getenv("bacio_ver") or "2.0.3"
load(pathJoin("bacio", bacio_ver))

jasper_ver=os.getenv("jasper_ver") or "1.900.1"
load(pathJoin("jasper", jasper_ver))

png_ver=os.getenv("png_ver") or "1.2.44"
load(pathJoin("png", png_ver))

z_ver=os.getenv("z_ver") or "1.2.11"
load(pathJoin("z", z_ver))


setenv("FCMP","ifort")
setenv("FFLAGSM","-O -xHost -list -auto")
setenv("LDFLAGSM","")
setenv("OMPFLAGM","")

whatis("Description: wave_stat build environment")
