cmake_minimum_required(VERSION 3.8.0)
project(LLVMJIT)

# Set dynamic linking to on
option(WAVM_ENABLE_STATIC_LINKING "use static linking instead of dynamic for the WAVM libraries" OFF)

# Bind some variables to useful paths
set(LLVMJIT_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR})
set(LLVMJIT_SOURCE_DIR ${LLVMJIT_ROOT_DIR}/src)
set(LLVMJIT_INCLUDE_DIR ${LLVMJIT_ROOT_DIR}/include)
set(WAVM_INCLUDE_DIR ${LLVMJIT_ROOT_DIR}/../wavm/Include)

# If no build type is specified, default to RelWithDebInfo
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
	set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "The type of build (Debug, Release, RelWithDebInfo, or MinSizeRel" FORCE)
endif()

# By default, CMake uses different optimization settings for Release vs RelWithDebInfo builds.
# For GCC, it uses -O3 in Release and -O2 in RelWithDebInfo.
# For MSVC, it uses /Ob2 in Release and /Ob1 in RelWithDebInfo (amount of inlining).
# In order to reduce problems that only occur in Release builds without debug symbols, override the
# default optimization settings so RelWithDebInfo uses the same optimization settings as Release.
set(CMAKE_C_FLAGS_RELWITHDEBINFO_LOCAL ${CMAKE_C_FLAGS_RELWITHDEBINFO})
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO_LOCAL ${CMAKE_CXX_FLAGS_RELWITHDEBINFO})
string(REPLACE "-O2" "-O3" CMAKE_C_FLAGS_RELWITHDEBINFO_LOCAL ${CMAKE_C_FLAGS_RELWITHDEBINFO_LOCAL})
string(REPLACE "-O2" "-O3" CMAKE_CXX_FLAGS_RELWITHDEBINFO_LOCAL ${CMAKE_CXX_FLAGS_RELWITHDEBINFO_LOCAL})
#string(REPLACE "-O3" "-O" CMAKE_C_FLAGS_RELEASE ${CMAKE_C_FLAGS_RELEASE})
#string(REPLACE "-O3" "-O" CMAKE_CXX_FLAGS_RELEASE ${CMAKE_CXX_FLAGS_RELEASE})
string(REPLACE "/Ob1" "/Ob2" CMAKE_C_FLAGS_RELWITHDEBINFO_LOCAL ${CMAKE_C_FLAGS_RELWITHDEBINFO_LOCAL})
string(REPLACE "/Ob1" "/Ob2" CMAKE_CXX_FLAGS_RELWITHDEBINFO_LOCAL ${CMAKE_CXX_FLAGS_RELWITHDEBINFO_LOCAL})
set(CMAKE_C_FLAGS_RELWITHDEBINFO ${CMAKE_C_FLAGS_RELWITHDEBINFO_LOCAL} CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO ${CMAKE_CXX_FLAGS_RELWITHDEBINFO_LOCAL} CACHE STRING "" FORCE)

# Create the LLVMJIT library
add_library(LLVMJIT SHARED
        ${LLVMJIT_SOURCE_DIR}/EmitConvert.cpp
		${LLVMJIT_SOURCE_DIR}/EmitCore.cpp
		${LLVMJIT_SOURCE_DIR}/EmitExceptions.cpp
		${LLVMJIT_SOURCE_DIR}/EmitFunction.cpp
		${LLVMJIT_SOURCE_DIR}/EmitMem.cpp
		${LLVMJIT_SOURCE_DIR}/EmitModule.cpp
		${LLVMJIT_SOURCE_DIR}/EmitNumeric.cpp
		${LLVMJIT_SOURCE_DIR}/EmitTable.cpp
		${LLVMJIT_SOURCE_DIR}/EmitVar.cpp
		${LLVMJIT_SOURCE_DIR}/LLVMCompile.cpp
		${LLVMJIT_SOURCE_DIR}/LLVMJIT.cpp
		${LLVMJIT_SOURCE_DIR}/LLVMModule.cpp
		${LLVMJIT_SOURCE_DIR}/Thunk.cpp
		${LLVMJIT_SOURCE_DIR}/Win64EH.cpp
		)
# Set private include directory
target_include_directories(LLVMJIT PRIVATE ${LLVMJIT_SOURCE_DIR})
set_target_properties(LLVMJIT PROPERTIES PUBLIC_HEADER ${LLVMJIT_INCLUDE_DIR}/LLVMJIT.h)

# Target C++11
target_compile_features(LLVMJIT PUBLIC cxx_std_14)

# Find an installed build of LLVM
find_package(LLVM REQUIRED CONFIG)

if(LLVM_VERSION_MAJOR LESS 6)
	message(FATAL_ERROR "WAVM requires LLVM version 6.0 or newer")
endif()

# Convert LLVM_DEFINITIONS and LLVM_INCLUDE_DIRS from strings of space-separated
# elements to strings of semicolon-separated elements (CMake lists)
separate_arguments(LLVM_DEFINITIONS)
separate_arguments(LLVM_INCLUDE_DIRS)

# LLVM on Windows includes a bunch of definitions in LLVM_DEFINITIONS to disable secure CRT
# warnings, which prevents the warnings from triggering in WAVM code as well. Remove them, since
# they doesn't seem to be necessary just to include LLVM.
list(REMOVE_ITEM LLVM_DEFINITIONS "-D_CRT_SECURE_NO_WARNINGS")
list(REMOVE_ITEM LLVM_DEFINITIONS "-D_CRT_SECURE_NO_DEPRECATE")
list(REMOVE_ITEM LLVM_DEFINITIONS "-D_CRT_NONSTDC_NO_DEPRECATE")
list(REMOVE_ITEM LLVM_DEFINITIONS "-D_CRT_NONSTDC_NO_WARNINGS")
list(REMOVE_ITEM LLVM_DEFINITIONS "-D_SCL_SECURE_NO_DEPRECATE")
list(REMOVE_ITEM LLVM_DEFINITIONS "-D_SCL_SECURE_NO_WARNINGS")

# Find the LLVM libraries to link with
llvm_map_components_to_libnames(LLVM_LIBS
		support
		core
		passes
		orcjit
		RuntimeDyld
		DebugInfoDWARF
		AllTargetsAsmParsers
		${LLVM_TARGETS_TO_BUILD})

target_compile_definitions(LLVMJIT PUBLIC ${LLVM_DEFINITIONS})
target_include_directories(LLVMJIT PUBLIC ${LLVM_INCLUDE_DIRS} ${WAVM_INCLUDE_DIR} ${LLVMJIT_INCLUDE_DIR})
target_link_libraries(LLVMJIT ${LLVM_LIBS})

include(GNUInstallDirs)

# Install libLLVMJIT.so to /usr/local/lib and LLVMJIT.h to /usr/local/include
install(TARGETS LLVMJIT
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# Set up the WAVM_API definitions
if(NOT WAVM_ENABLE_STATIC_LINKING AND MSVC)
	target_compile_definitions(LLVMJIT PRIVATE "\"WAVM_API=__declspec(dllexport)\"")
	target_compile_definitions(LLVMJIT INTERFACE "\"WAVM_API=__declspec(dllimport)\"")
	target_compile_definitions(LLVMJIT INTERFACE "\"WAVM_API=__declspec(dllimport)\"")
elseif(NOT WAVM_ENABLE_STATIC_LINKING AND CXX_HAS_FVISIBILITY_HIDDEN)
	target_compile_definitions(LLVMJIT PUBLIC "WAVM_API=__attribute__((visibility(\"default\")))")
else()
	target_compile_definitions(LLVMJIT PUBLIC "WAVM_API=")
endif()