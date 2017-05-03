# This a sample CMakeLists.txt for compiling indicatos for Wingpanel
# http://elementaryos.org/docs/developer-guide/cmake

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)

# Set the Title to use for the Indicator (May be used in future features)
set (INDICATORTITLE "Sound")

# The description of what your Indicator is
set (INDICATORDESCRIPTION "Sound indicator")

# Projectname
project (sound)

#########################################################
# Only alter stuff below if you know what you are doing #
#########################################################

# Configuration
include (GNUInstallDirs)
set (DATADIR "${CMAKE_INSTALL_FULL_LIBDIR}/wingpanel")
set (PKGDATADIR "${DATADIR}")
set (GETTEXT_PACKAGE "${CMAKE_PROJECT_NAME}-indicator")
set (VERSION "2.0.5")
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/config.vala.cmake ${CMAKE_BINARY_DIR}/src/config.vala)
add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

# Comment this out to enable C compiler warnings
add_definitions (-w)

# Files
file (GLOB resources "${CMAKE_CURRENT_SOURCE_DIR}/data/*")

# Translations
add_subdirectory (po)

# Code
add_subdirectory(src)

# GSettings schema
add_subdirectory (schemas)

# Uninstall target
 configure_file(
     "${CMAKE_SOURCE_DIR}/cmake/Uninstall.cmake"
     "${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake"
     IMMEDIATE @ONLY)

 add_custom_target(uninstall
     COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake)
