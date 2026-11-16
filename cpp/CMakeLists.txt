cmake_minimum_required(VERSION 3.16)
project(kdb_trading_lab_cpp CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()
add_compile_options(-Wall -Wextra -Wno-unused-parameter)

# k.h and c.o come from https://github.com/KxSystems/kdb  (c/c/k.h and l64/c.o)
# Put them in cpp/third_party/ (bin/get_c_api.sh does this) or pass -DKDB_C_API_DIR=...
set(KDB_C_API_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party" CACHE PATH "dir with k.h and c.o")
if(NOT EXISTS "${KDB_C_API_DIR}/k.h")
  message(FATAL_ERROR "k.h not found in ${KDB_C_API_DIR}. Run bin/get_c_api.sh")
endif()
include_directories(${KDB_C_API_DIR})
find_package(Threads REQUIRED)

# Clients: link the c.o object (IPC + K memory management)
foreach(app feed_handler query_client)
  add_executable(${app} ${app}.cpp)
  target_link_libraries(${app} "${KDB_C_API_DIR}/c.o" Threads::Threads ${CMAKE_DL_LIBS})
endforeach()

# Shared library loaded into q with 2: - no c.o, symbols come from the q executable
add_library(qudf SHARED qudf.cpp)
target_compile_options(qudf PRIVATE -O3 -march=native)
set_target_properties(qudf PROPERTIES POSITION_INDEPENDENT_CODE ON)

# Unit tests for the UDFs, run outside q (c.o provides the K memory functions)
add_executable(test_qudf test_qudf.cpp qudf.cpp)
target_link_libraries(test_qudf "${KDB_C_API_DIR}/c.o" Threads::Threads ${CMAKE_DL_LIBS})
target_compile_options(test_qudf PRIVATE -UNDEBUG)
enable_testing()
add_test(NAME qudf COMMAND test_qudf)
