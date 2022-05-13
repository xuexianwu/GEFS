help([[
Load environment for building gefs_nstgen on hera
]])

intel_ver=os.getenv("intel_ver") or "18.0.5.274"
load(pathJoin("intel", intel_ver))

impi_ver=os.getenv("impi_ver") or "2018.0.4"
load(pathJoin("impi", impi_ver))


w3nco_ver=os.getenv("w3nco_ver") or "2.0.7"
load(pathJoin("w3nco", w3nco_ver))

bacio_ver=os.getenv("bacio_ver") or "2.0.3"
load(pathJoin("bacio", bacio_ver))

netcdf_ver=os.getenv("netcdf_ver") or "4.7.0"
load(pathJoin("netcdf", netcdf_ver))


setenv("FCMP","ifort")
setenv("LDFLAGSM","")
setenv("OMPFLAGM","")

--setenv("NETCDF_INC","${NETCDF}/include")
--setenv("NETCDF_LDFLAGS","-L${NETCDF}/lib -lnetcdff")

setenv("NETCDF_INCLUDES","${NETCDF}/include")
setenv("NETCDF_LIBRARIES","${NETCDF}/lib")
setenv("NETCDF_LDFLAGS","-L${NETCDF_LIBRARIES} -lnetcdff")

whatis("Description: gefs_nstgen build environment")
