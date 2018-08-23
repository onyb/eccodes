# (C) Copyright 1996-2016 ECMWF.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
# In applying this licence, ECMWF does not waive the privileges and immunities
# granted to it by virtue of its status as an intergovernmental organisation
# nor does it submit to any jurisdiction.

set( CMAKE_Fortran_FLAGS_RELEASE        "-O3 -funroll-all-loops -finline-functions"                                CACHE STRING "Fortran compiler flags for Release builds"          FORCE )
set( CMAKE_Fortran_FLAGS_BIT            "-g -O2 -m64 -march=native -DNDEBUG -fno-range-check -fconvert=big-endian" CACHE STRING "Fortran compiler flags for Bit-reproducible builds" FORCE )
set( CMAKE_Fortran_FLAGS_DEBUG          "-O0 -g -fcheck=bounds -fbacktrace -finit-real=snan"                       CACHE STRING "Fortran compiler flags for Debug builds"            FORCE )
set( CMAKE_Fortran_FLAGS_PRODUCTION     "-O2 -g"                                                                   CACHE STRING "Fortran compiler flags for Production builds."      FORCE )
set( CMAKE_Fortran_FLAGS_RELWITHDEBINFO "-O2 -g"                                                                   CACHE STRING "Fortran compiler flags for RelWithDebInfo builds."  FORCE )

####################################################################

# Meaning of flags
# ----------------
# -fstack-arrays     : Allocate automatic arrays on the stack (needs large stacksize!!!)
# -funroll-all-loops : Unroll all loops
# -fcheck=bounds     : Bounds checking
