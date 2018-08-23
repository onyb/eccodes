###############################################################################
#
# CMake module to search for GeoTIFF library
#
# On success, the macro sets the following variables:
# GEOTIFF_FOUND       = if the library found
# GEOTIFF_LIBRARIES   = full path to the library
# GEOTIFF_INCLUDE_DIR = where to find the library headers 
# also defined, but not for general use are
# GEOTIFF_LIBRARY, where to find the PROJ.4 library.
#
# Copyright (c) 2009 Mateusz Loskot <mateusz@loskot.net>
#
# Module source: http://github.com/mloskot/workshop/tree/master/cmake/
#
# Redistribution and use is allowed according to the terms of the BSD license.
# For details see the accompanying COPYING-CMAKE-SCRIPTS file.
#
###############################################################################

SET(GEOTIFF_NAMES geotiff)


    FIND_PATH(GEOTIFF_INCLUDE_DIR geotiff.h PATH_PREFIXES geotiff 
         PATHS /usr/local/include/libgeotiff /usr/include/libgeotiff)

    FIND_LIBRARY(GEOTIFF_LIBRARY NAMES ${GEOTIFF_NAMES})


IF(GEOTIFF_FOUND)
  SET(GEOTIFF_LIBRARIES ${GEOTIFF_LIBRARY})
ENDIF()

# Handle the QUIET and REQUIRED arguments and set GEOTIFF_FOUND to TRUE
# if all listed variables are TRUE
# Note: capitalisation of the package name must be the same as in the file name
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(GEOTiff DEFAULT_MSG GEOTIFF_LIBRARY GEOTIFF_INCLUDE_DIR)
