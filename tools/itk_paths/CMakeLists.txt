cmake_minimum_required(VERSION 3.16)
project(itk_paths CXX)

if(DEFINED ENV{ITK_DIR} AND NOT "$ENV{ITK_DIR}" STREQUAL "")
  set(ITK_DIR "$ENV{ITK_DIR}" CACHE PATH "ITK config directory" FORCE)
endif()

file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/../itk_modules.txt" ITKLIB_MODULES REGEX "^[A-Za-z]")
find_package(ITK 5.4.8 REQUIRED COMPONENTS ${ITKLIB_MODULES})
include(${ITK_USE_FILE})

file(WRITE "${CMAKE_BINARY_DIR}/itk_meta.txt"
  "version=${ITK_VERSION}\nlibdirs=${ITK_LIBRARY_DIRS}\n")

add_library(probe SHARED probe.cpp)
target_link_libraries(probe PRIVATE ${ITK_LIBRARIES})
target_compile_features(probe PRIVATE cxx_std_17)
