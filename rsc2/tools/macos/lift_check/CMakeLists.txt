cmake_minimum_required(VERSION 3.20)
project(lift_check C)
# The lifter's output for the synthetic XBE (xboxrecomp/tools/conformance/
# mkxbe.py), built for this host and executed: see check_lifter.sh.
set(CMAKE_C_STANDARD 11)
if(NOT GEN_DIR)
    message(FATAL_ERROR "set -DGEN_DIR to the generated code (check_lifter.sh does)")
endif()
add_subdirectory(../../../../xboxrecomp runtime)
file(GLOB GEN_SOURCES ${GEN_DIR}/*.c)
add_executable(lift_check lift_check.c ${GEN_SOURCES})
set_source_files_properties(${GEN_SOURCES} PROPERTIES COMPILE_OPTIONS "-fno-strict-aliasing;-fwrapv;-w")
target_include_directories(lift_check PRIVATE ${GEN_DIR} ../../../../xboxrecomp/src/kernel)
target_link_libraries(lift_check PRIVATE xboxrecomp)
