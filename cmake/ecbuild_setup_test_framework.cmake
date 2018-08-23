ecbuild_add_option( FEATURE TESTS
                    DEFAULT ON
                    DESCRIPTION "Enable the unit tests" )

if( ENABLE_TESTS AND CMAKE_CXX_COMPILER_LOADED )

  # Try to find compiled boost

  # BOOST_ROOT or BOOSTROOT should take precedence on the search for location
  if( BOOST_ROOT OR BOOSTROOT OR DEFINED ENV{BOOST_ROOT} OR DEFINED ENV{BOOSTROOT} )
    set( CMAKE_PREFIX_PATH ${BOOST_ROOT} ${BOOSTROOT} $ENV{BOOST_ROOT} $ENV{BOOSTROOT} ${CMAKE_PREFIX_PATH} )
  endif()

  set( Boost_USE_MULTITHREADED  ON )
  #   set( Boost_DEBUG              ON )

  find_package( Boost 1.47.0 COMPONENTS unit_test_framework )

  set( ECBUILD_BOOST_HEADER_DIRS "${CMAKE_CURRENT_LIST_DIR}/include" )

  if( Boost_FOUND AND Boost_UNIT_TEST_FRAMEWORK_LIBRARY )

    set( HAVE_BOOST_UNIT_TEST 1 )
    set( BOOST_UNIT_TEST_FRAMEWORK_LINKED 1 )

    ecbuild_info( "Using Boost for unit tests:\n    INC [${Boost_INCLUDE_DIRS}]\n    LIB [${Boost_UNIT_TEST_FRAMEWORK_LIBRARY}]" )

  else()

    ecbuild_info( "Boost unit test framework -- NOT FOUND" )

    set( HAVE_BOOST_UNIT_TEST 0 )

    # set( BOOST_UNIT_TEST_FRAMEWORK_HEADER_ONLY 1 )
    # comment out this when ecbuild packs boost unit test inside...
    # list( APPEND ECBUILD_BOOST_HEADER_DIRS "${CMAKE_CURRENT_LIST_DIR}/contrib/boost-1.55/include" )
    # set( HAVE_BOOST_UNIT_TEST 1 )

  endif()

endif()

if( NOT ENABLE_TESTS )
  ecbuild_info("Tests have been disabled")
endif()
