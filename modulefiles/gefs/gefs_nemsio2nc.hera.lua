help([[
Load environment for building gefs_nesio2nc on hera
]])

-- prepend_path("MODULEPATH", "/scratch2/NCEPDEV/nwprod/hpc-stack/libs/hpc-stack-gfsv16/modulefiles/stack")
prepend_path("MODULEPATH", "/scratch2/NCEPDEV/nwprod/NCEPLIBS/modulefiles")

intel_ver=os.getenv("intel_ver") or "18.0.5.274"
load(pathJoin("intel", intel_ver))

impi_ver=os.getenv("impi_ver") or "2018.0.4"
load(pathJoin("impi", impi_ver))


nemsio_ver=os.getenv("nemsio_ver") or "2.2.4"
load(pathJoin("nemsio", nemsio_ver))

w3nco_ver=os.getenv("w3nco_ver") or "2.0.7"
load(pathJoin("w3nco", w3nco_ver))

bacio_ver=os.getenv("bacio_ver") or "2.0.3"
load(pathJoin("bacio", bacio_ver))

netcdf_parallel_ver=os.getenv("netcdf_parallel_ver") or "4.7.4"
load(pathJoin("netcdf_parallel", netcdf_parallel_ver))


setenv("FCMP","ifort")
setenv("LDFLAGSM","")
setenv("OMPFLAGM","")

whatis("Description: gefs_nesio2nc build environment")