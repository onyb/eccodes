#
# Copyright 2005-2018 ECMWF.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
#
# In applying this licence, ECMWF does not waive the privileges and immunities
# granted to it by virtue of its status as an intergovernmental organisation
# nor does it submit to any jurisdiction.
#
###############################################################################
# cmake options:
#
#       -DCMAKE_BUILD_TYPE=Debug|RelWithDebInfo|Release|Production
#       -DCMAKE_INSTALL_PREFIX=/path/to/install
#
#       -DCMAKE_MODULE_PATH=/path/to/ecbuild/cmake

cmake_minimum_required( VERSION 2.8.11 FATAL_ERROR )

project( eccodes C )

set( CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/../ecbuild/cmake")

include( ecbuild_system NO_POLICY_SCOPE )

ecbuild_requires_macro_version( 2.7.2 )

###############################################################################
# local project

ecbuild_declare_project()

###############################################################################
# system checks needed for eccodes_config.h and some options like MEMFS

check_type_size( int            ECCODES_SIZEOF_INT    )
check_type_size( long           ECCODES_SIZEOF_LONG   )
check_type_size( size_t         ECCODES_SIZEOF_SIZE_T )

check_include_files( assert.h         ECCODES_HAVE_ASSERT_H      )
check_include_files( string.h         ECCODES_HAVE_STRING_H      )
check_include_files( sys/types.h      ECCODES_HAVE_SYS_TYPES_H   )
check_include_files( sys/stat.h       ECCODES_HAVE_SYS_STAT_H    )
check_include_files( fcntl.h          ECCODES_HAVE_FCNTL_H      )
check_include_files( unistd.h         ECCODES_HAVE_UNISTD_H      )

check_symbol_exists( fseeko           "stdio.h"    ECCODES_HAVE_FSEEKO )
check_symbol_exists( posix_memalign   "stdlib.h"   ECCODES_HAVE_POSIX_MEMALIGN )
check_symbol_exists( fmemopen         "stdio.h"    ECCODES_HAVE_FMEMOPEN )
check_symbol_exists( funopen          "stdio.h"    ECCODES_HAVE_FUNOPEN )

check_c_source_compiles(
      " typedef int foo_t;
      static inline foo_t static_foo(){return 0;}
      foo_t foo(){return 0;}
      int main(int argc, char *argv[]){return 0;}
      " ECCODES_HAVE_C_INLINE )

include(eccodes_test_endiness)

ecbuild_debug("ECCODES_BIG_ENDIAN=${ECCODES_BIG_ENDIAN}")
ecbuild_debug("ECCODES_LITTLE_ENDIAN=${ECCODES_LITTLE_ENDIAN}")

###############################################################################
# some variables/options of this project

ecbuild_add_option( FEATURE EXAMPLES
    DESCRIPTION "Build the examples"
    DEFAULT ON
)

ecbuild_add_option( FEATURE JPG
    DESCRIPTION "Support for JPG decoding/encoding"
    DEFAULT ON
)

ecbuild_add_option( FEATURE PNG
    DESCRIPTION "Support for PNG decoding/encoding"
    DEFAULT OFF
    REQUIRED_PACKAGES PNG
)

if( HAVE_PNG )
    set( HAVE_LIBPNG 1 ) # compatibility with autotools
    add_definitions( ${PNG_DEFINITIONS} )
else()
    set( HAVE_LIBPNG 0 )
endif()

ecbuild_add_option( FEATURE NETCDF
    DESCRIPTION "Support for GRIB to NetCDF conversion"
    DEFAULT ON
    REQUIRED_PACKAGES NetCDF
    NO_TPL
)

ecbuild_add_option( FEATURE AEC
    DESCRIPTION "Support for Adaptive Entropy Coding"
    DEFAULT OFF
    REQUIRED_PACKAGES AEC
)

ecbuild_add_option( FEATURE PYTHON
    DESCRIPTION "Build the ecCodes Python interface"
    DEFAULT ON
    REQUIRED_PACKAGES "Python VERSION 2.6 NO_LIBS" NumPy
)

ecbuild_add_option( FEATURE FORTRAN
    DESCRIPTION "Build the ecCodes Fortran interface"
    DEFAULT ON
    # REQUIRED_LANGUAGES Fortran # TODO
)

# TODO Remove this after REQUIRED_LANGUAGES
if( ENABLE_FORTRAN )
    # will set EC_HAVE_FORTRAN with the result
    set( EC_HAVE_FORTRAN 0 )
    ecbuild_enable_fortran( MODULE_DIRECTORY ${PROJECT_BINARY_DIR}/fortran/modules )
    set( HAVE_FORTRAN ${EC_HAVE_FORTRAN} )
else()
    set( HAVE_FORTRAN 0 )
endif()

# memfs requires only Python executable and not its libraries
ecbuild_add_option( FEATURE MEMFS
    DESCRIPTION "Memory based access to definitions/samples"
    DEFAULT OFF
    CONDITION ECCODES_HAVE_FMEMOPEN OR ECCODES_HAVE_FUNOPEN
    REQUIRED_PACKAGES PythonInterp
)

#if( HAVE_MEMFS AND "${CMAKE_C_COMPILER_ID}" STREQUAL "Cray")
#  set( HAVE_MEMFS OFF )
#  ecbuild_warn("MEMFS not supported with Cray C compiler")
#endif()

if(HAVE_MEMFS)
  set( _will_install_defs_samples OFF )
else()
  set( _will_install_defs_samples ON )
endif()

# controls installation of files in definitions/ -- note that it still creates the symlinks in the build dir
# by default, if memfs is available, then we don't need to install definitions
ecbuild_add_option( FEATURE INSTALL_ECCODES_DEFINITIONS
    DESCRIPTION "Install the ecCodes definitions"
    DEFAULT ${_will_install_defs_samples}
)

# controls installation of files in samples/ and ifs_samples/ -- note that it still creates the symlinks in the build dir
# by default, if memfs is available, then we don't need to install samples
ecbuild_add_option( FEATURE INSTALL_ECCODES_SAMPLES
    DESCRIPTION "Install the ecCodes samples, including IFS samples"
    DEFAULT ${_will_install_defs_samples}
)

# advanced options (not visible in cmake-gui )

ecbuild_add_option( FEATURE MEMORY_MANAGEMENT   DESCRIPTION "Enable memory management" DEFAULT OFF ADVANCED )
ecbuild_add_option( FEATURE ALIGN_MEMORY        DESCRIPTION "Enable memory alignment"  DEFAULT OFF ADVANCED )
ecbuild_add_option( FEATURE GRIB_TIMER          DESCRIPTION "Enable timer" DEFAULT OFF ADVANCED )
ecbuild_add_option( FEATURE ECCODES_THREADS     DESCRIPTION "Enable POSIX threads" DEFAULT OFF ADVANCED )
ecbuild_add_option( FEATURE ECCODES_OMP_THREADS DESCRIPTION "Enable OMP threads" DEFAULT OFF ADVANCED )
ecbuild_add_option( FEATURE EXTRA_TESTS         DESCRIPTION "Enable extended regression testing" DEFAULT OFF ADVANCED )

###############################################################################
# macro processing

set( ECCODES_EXTRA_LIBRARIES    "" )
set( ECCODES_EXTRA_INCLUDE_DIRS "" )
set( ECCODES_EXTRA_DEFINITIONS  "" )

find_package( CMath )
list( APPEND ECCODES_TPLS CMath )

### JPG support

set( HAVE_JPEG 0 )
set( HAVE_LIBJASPER 0 )
set( HAVE_LIBOPENJPEG 0 )

if( ENABLE_JPG )

    # Note: This is a deprecated feature but we need it to find Jasper at ECMWF.
    #       ecbuild_add_extra_search_paths modifies CMAKE_PREFIX_PATH
    #       which can affect future package discovery if not undone by the caller.
    #       The current CMAKE_PREFIX_PATH is backed up as _CMAKE_PREFIX_PATH
    #
    set(CMAKE_WARN_DEPRECATED OFF) # Suppress deprecation message
    ecbuild_add_extra_search_paths( jasper )
    find_package( Jasper )
    set(CMAKE_PREFIX_PATH ${_CMAKE_PREFIX_PATH})    # Restore CMAKE_PREFIX_PATH
    set(CMAKE_WARN_DEPRECATED ON)  # Remove suppression

    find_package( OpenJPEG )

    if( JASPER_FOUND )
        list( APPEND ECCODES_TPLS Jasper )
        set( HAVE_JPEG 1 )
        set( HAVE_LIBJASPER 1 )
        # Extract Jasper's major version number to enable conditional code. See ECC-396
        string(REGEX REPLACE "^([0-9]+)\\.[0-9]+\\.[0-9]+.*" "\\1" JASPER_VERSION_MAJOR "${JASPER_VERSION_STRING}")
    endif()

    if( OPENJPEG_FOUND )
        list( APPEND ECCODES_TPLS OpenJPEG )
        set( HAVE_JPEG 1 )
        set( HAVE_LIBOPENJPEG 1 )
    endif()

endif()


###############################################################################
# other options

if( HAVE_GRIB_TIMER )
    set( GRIB_TIMER 1 )
else()
    set( GRIB_TIMER 0 )
endif()

set( IS_BIG_ENDIAN 0 )
if( ECCODES_BIG_ENDIAN )
    set( IS_BIG_ENDIAN 1 )
endif()

set( MANAGE_MEM 0 )
if( ENABLE_MEMORY_MANAGEMENT )
    set( MANAGE_MEM 1 )
endif()

set( CMAKE_THREAD_PREFER_PTHREAD 1 ) # find thread library, but prefer pthreads
find_package(Threads REQUIRED)

# debug
ecbuild_info(" CMAKE_THREAD_LIBS_INIT=${CMAKE_THREAD_LIBS_INIT}")
ecbuild_info(" CMAKE_USE_PTHREADS_INIT=${CMAKE_USE_PTHREADS_INIT}")
ecbuild_info(" HAVE_ECCODES_THREADS=${HAVE_ECCODES_THREADS}")


set( GRIB_PTHREADS 0 )
set( GRIB_OMP_THREADS 0 )
set( GRIB_LINUX_PTHREADS 0 )
#if( HAVE_ECCODES_THREADS AND CMAKE_THREAD_LIBS_INIT )
if( HAVE_ECCODES_THREADS )
    if( NOT ${CMAKE_USE_PTHREADS_INIT} )
        ecbuild_critical("Pthreads is not supported on your system: thread library found=[${CMAKE_THREAD_LIBS_INIT}]")
    endif()
    set( GRIB_PTHREADS 1 )
    if( ${CMAKE_SYSTEM_NAME} MATCHES "Linux" )
        set( GRIB_LINUX_PTHREADS 1 )
    endif()
elseif(HAVE_ECCODES_OMP_THREADS)
    ecbuild_enable_omp()
    set( GRIB_OMP_THREADS 1 )
endif()

# Cannot have both options
if( HAVE_ECCODES_THREADS AND HAVE_ECCODES_OMP_THREADS )
    ecbuild_critical("Cannot enable both POSIX threads and OMP! Please specify just one option")
endif()

ecbuild_info(" GRIB_PTHREADS=${GRIB_PTHREADS}")
ecbuild_info(" GRIB_OMP_THREADS=${GRIB_OMP_THREADS}")

set( GRIB_MEM_ALIGN 0 )
if( ENABLE_ALIGN_MEMORY )
  set( GRIB_MEM_ALIGN 1 )
endif()

# fix for #if IEEE_LE or IEE_BE instead of #ifdef

if( IEEE_BE )
    set( IEEE_LE 0 )
endif()

if( IEEE_LE )
    set( IEEE_BE 0 )
endif()

###############################################################################
# contents

if( NOT ${DEVELOPER_MODE} )
    set( the_default_data_prefix ${CMAKE_INSTALL_PREFIX} )
else()
    set( the_default_data_prefix ${CMAKE_BINARY_DIR} )
endif()

if( NOT DEFINED ECCODES_DEFINITION_SUFF )
  set( ECCODES_DEFINITION_SUFF  ${INSTALL_DATA_DIR}/definitions )
endif()
if( NOT DEFINED ECCODES_SAMPLES_SUFF )
  set( ECCODES_SAMPLES_SUFF     ${INSTALL_DATA_DIR}/samples )
endif()
if( NOT DEFINED ECCODES_IFS_SAMPLES_SUFF )
  set( ECCODES_IFS_SAMPLES_SUFF ${INSTALL_DATA_DIR}/ifs_samples )
endif()

set( ECCODES_DEFINITION_PATH  ${the_default_data_prefix}/${ECCODES_DEFINITION_SUFF} )
set( ECCODES_SAMPLES_PATH     ${the_default_data_prefix}/${ECCODES_SAMPLES_SUFF} )
set( ECCODES_IFS_SAMPLES_PATH ${the_default_data_prefix}/${ECCODES_IFS_SAMPLES_SUFF} )

###############################################################################
### config header

ecbuild_generate_config_headers()

configure_file( eccodes_config.h.in eccodes_config.h )

add_definitions( -DHAVE_ECCODES_CONFIG_H )

install( FILES ${CMAKE_CURRENT_BINARY_DIR}/eccodes_config.h DESTINATION ${INSTALL_INCLUDE_DIR} )

if( CMAKE_COMPILER_IS_GNUCC )
    ecbuild_add_c_flags("-pedantic")
endif()

###############################################################################
# contents

### export package to other ecbuild packages

set( ECCODES_INCLUDE_DIRS    ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/src ${CMAKE_CURRENT_BINARY_DIR}/src )
set( ECCODES_LIBRARIES       eccodes )

get_directory_property( COMPILE_DEFINITIONS ECCODES_DEFINITIONS )

foreach( _tpl ${ECCODES_TPLS} )
    string( TOUPPER ${_tpl} TPL )
    if( ${TPL}_FOUND )
        list( APPEND ECCODES_EXTRA_DEFINITIONS   ${${TPL}_DEFINITIONS} )
        list( APPEND ECCODES_EXTRA_INCLUDE_DIRS  ${${TPL}_INCLUDE_DIRS} ${${TPL}_INCLUDE_DIR} )
        list( APPEND ECCODES_EXTRA_LIBRARIES     ${${TPL}_LIBRARIES} )
    endif()
endforeach()

### include directories

include_directories( ${ECCODES_INCLUDE_DIRS}  ${ECCODES_EXTRA_INCLUDE_DIRS} )

add_subdirectory( definitions ) # must be before memfs
add_subdirectory( memfs )
add_subdirectory( src )
add_subdirectory( tools )
add_subdirectory( fortran )
add_subdirectory( python )
add_subdirectory( tests )
add_subdirectory( tigge )
add_subdirectory( examples )
add_subdirectory( data )
add_subdirectory( samples )
add_subdirectory( ifs_samples ) # must come after samples

# ecbuild_dont_pack( DIRS samples DONT_PACK_REGEX "*.grib" )
ecbuild_dont_pack( DIRS
     concepts tests.ecmwf doxygen confluence examples.dev templates parameters java
     perl config m4 rpms gaussian_experimental gribex examples/F77
     examples/extra examples/deprecated bamboo fortran/fortranCtypes tigge/tools
     share/eccodes  .settings
)
#ecbuild_dont_pack( DIRS data/bufr  DONT_PACK_REGEX "*.bufr" )
#ecbuild_dont_pack( DIRS data/tigge DONT_PACK_REGEX "*.grib" )

add_custom_target(dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

###############################################################################
# export to other projects

# temporary -- add support for ecbuild 1.0.x sub-project inclusion
# to remove once mars server & client use eckit & ecbuild >= 1.1

if( HAVE_FORTRAN )
    list( APPEND ECCODES_INCLUDE_DIRS  ${CMAKE_Fortran_MODULE_DIRECTORY} )
    list( APPEND ECCODES_LIBRARIES eccodes_f90 )
endif()

# Bundle
if( NOT PROJECT_NAME STREQUAL CMAKE_PROJECT_NAME )
  set( ECCODES_FOUND            TRUE PARENT_SCOPE )
  set( ECCODES_DEFINITIONS      ${ECCODES_DEFINITIONS}  PARENT_SCOPE )# includes already TPL definitions
  set( ECCODES_INCLUDE_DIRS     ${ECCODES_INCLUDE_DIRS} ${ECCODES_EXTRA_INCLUDE_DIRS} PARENT_SCOPE )
  set( ECCODES_LIBRARIES        ${ECCODES_LIBRARIES}    ${ECCODES_EXTRA_LIBRARIES} PARENT_SCOPE )
  set( ECCODES_INSTALL_EXTRA_TOOLS  ${ECCODES_INSTALL_EXTRA_TOOLS} PARENT_SCOPE )
  set( ECCODES_DEFINITION_PATH  ${CMAKE_BINARY_DIR}/${ECCODES_DEFINITION_SUFF}  PARENT_SCOPE )
  set( ECCODES_SAMPLES_PATH     ${CMAKE_BINARY_DIR}/${ECCODES_SAMPLES_SUFF}     PARENT_SCOPE )
  set( ECCODES_IFS_SAMPLES_PATH ${CMAKE_BINARY_DIR}/${ECCODES_IFS_SAMPLES_SUFF} PARENT_SCOPE )
endif()

# pkg-config
ecbuild_pkgconfig(
  NAME           eccodes
  URL            "https://software.ecmwf.int/wiki/display/ECC/"
  DESCRIPTION    "The ecCodes library"
  LIBRARIES      eccodes
  IGNORE_INCLUDE_DIRS ${PYTHON_INCLUDE_DIRS} ${NUMPY_INCLUDE_DIRS} ${NETCDF_INCLUDE_DIRS}
  VARIABLES      HAVE_MEMFS HAVE_JPEG HAVE_LIBJASPER HAVE_LIBOPENJPEG
                 HAVE_ECCODES_THREADS HAVE_ECCODES_OMP_THREADS
                 HAVE_NETCDF HAVE_PYTHON HAVE_FORTRAN HAVE_PNG HAVE_AEC
)
if( HAVE_FORTRAN )
  ecbuild_pkgconfig(
    NAME                eccodes_f90
    URL                 "https://software.ecmwf.int/wiki/display/ECC/"
    LIBRARIES           eccodes_f90 eccodes
    DESCRIPTION         "The ecCodes library for Fortran 90"
    IGNORE_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/fortran ${PROJECT_BINARY_DIR}/fortran
                        ${PYTHON_INCLUDE_DIRS} ${NUMPY_INCLUDE_DIRS} ${NETCDF_INCLUDE_DIRS}
    VARIABLES           HAVE_MEMFS HAVE_JPEG HAVE_LIBJASPER HAVE_LIBOPENJPEG
                        HAVE_ECCODES_THREADS HAVE_ECCODES_OMP_THREADS
                        HAVE_NETCDF HAVE_PYTHON HAVE_PNG HAVE_AEC
  )
endif()

###############################################################################
# finalize

ecbuild_install_project( NAME ${CMAKE_PROJECT_NAME} )

ecbuild_print_summary()

ecbuild_info("")
ecbuild_info("   +--------------------------+")
ecbuild_info("   |  ecCodes version ${ECCODES_VERSION}   |")
ecbuild_info("   +--------------------------+")
ecbuild_info("")
