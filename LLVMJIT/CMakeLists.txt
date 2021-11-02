cmake_minimum_required(VERSION 3.8.0)

project(LLVMJIT)

# WAVM configuration options
option(WAVM_ENABLE_STATIC_LINKING "use static linking instead of dynamic for the WAVM libraries" OFF)
option(WAVM_ENABLE_RELEASE_ASSERTS "enable assertions in release builds" 0)
set(WAVM_ENABLE_LTO "OFF" CACHE STRING "enable link-time optimization (off, on, or thin)")

# Find an installed build of LLVM
find_package(LLVM REQUIRED CONFIG)

if(LLVM_VERSION_MAJOR LESS 6)
	message(FATAL_ERROR "WAVM requires LLVM version 6.0 or newer")
endif()

# Bind some variables to useful paths.
set(LLVMJIT_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR})
set(LLVMJIT_SOURCE_DIR src)
set(LLVMJIT_INCLUDE_DIR include)

include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

# Convert LLVM_DEFINITIONS and LLVM_INCLUDE_DIRS from strings of space-separated elements to
# CMake lists (strings with semicolon-separated elements).
separate_arguments(LLVM_DEFINITIONS)
separate_arguments(LLVM_INCLUDE_DIRS)

# Put executables/DLLs in the <build>/bin directory.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${LLVMJIT_ROOT_DIR}/bin)
#add_library(LLVMJIT SHARED IMPORTED)

# Install LLVMJIT/include to <install root>/include/LLVMJIT
install(DIRECTORY
		COMPONENT devel
		DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/include
		PATTERN *.txt EXCLUDE
		PATTERN *.h.in EXCLUDE)

# Find the LLVM libraries to link with.
llvm_map_components_to_libnames(LLVM_LIBS
		support
		core
		passes
		orcjit
		RuntimeDyld
		DebugInfoDWARF
		AllTargetsAsmParsers
		${LLVM_TARGETS_TO_BUILD})

set(Sources
        src/EmitContext.h
        src/EmitConvert.cpp
        src/EmitCore.cpp
        src/EmitExceptions.cpp
        src/EmitFunction.cpp
        src/EmitFunctionContext.h
        src/EmitMem.cpp
        src/EmitModule.cpp
        src/EmitModuleContext.h
        src/EmitNumeric.cpp
        src/EmitTable.cpp
        src/EmitVar.cpp
        src/EmitWorkarounds.h
        src/LLVMCompile.cpp
        src/LLVMJIT.cpp
        src/LLVMJITPrivate.h
        src/LLVMModule.cpp
        src/Thunk.cpp
        src/Win64EH.cpp)
set(PublicHeaders
		${LLVMJIT_INCLUDE_DIR}/LLVMJIT.h)

add_library(LLVMJIT SHARED
        src/EmitConvert.cpp
        src/EmitCore.cpp
        src/EmitExceptions.cpp
        src/EmitFunction.cpp
        src/EmitMem.cpp
        src/EmitModule.cpp
        src/EmitNumeric.cpp
        src/EmitTable.cpp
        src/EmitVar.cpp
        src/LLVMCompile.cpp
        src/LLVMJIT.cpp
        src/LLVMModule.cpp
        src/Thunk.cpp
        src/Win64EH.cpp
		)
set_target_properties(LLVMJIT PROPERTIES PUBLIC_HEADER ${LLVMJIT_INCLUDE_DIR}/LLVMJIT.h)

# Target C++11.
target_include_directories(LLVMJIT PUBLIC
		PUBLIC $<INSTALL_INTERFACE:include>
		$<BUILD_INTERFACE:${LLVMJIT_ROOT_DIR}/include>
		$<BUILD_INTERFACE:${LLVMJIT_ROOT_DIR}/include>)
target_compile_features(LLVMJIT PUBLIC cxx_std_14)
target_link_libraries(LLVMJIT ${llvm_libs})

include(GNUInstallDirs)
install(TARGETS LLVMJIT
		EXPORT LLVMJITInstallTargets COMPONENT devel
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# Set up the WAVM_API definitions.
if(NOT WAVM_ENABLE_STATIC_LINKING AND MSVC)
	target_compile_definitions(LLVMJIT PRIVATE "\"WAVM_API=__declspec(dllexport)\"")
	target_compile_definitions(LLVMJIT INTERFACE "\"WAVM_API=__declspec(dllimport)\"")
elseif(NOT WAVM_ENABLE_STATIC_LINKING AND CXX_HAS_FVISIBILITY_HIDDEN)
	target_compile_definitions(LLVMJIT PUBLIC "WAVM_API=__attribute__((visibility(\"default\")))")
else()
	target_compile_definitions(LLVMJIT PUBLIC "WAVM_API=")
endif()

# Create a CMake package in <build>/lib/cmake/WAVM containing the WAVM library targets.
export(
		EXPORT LLVMJITInstallTargets
		FILE ${CMAKE_CURRENT_BINARY_DIR}/lib/cmake/LLVMJIT/LLVMJIT.cmake
		NAMESPACE LLVMJIT::)
# Create a CMake package in <install root>/lib/cmake/WAVM containing the WAVM library targets.
install(
		EXPORT LLVMJITInstallTargets
		COMPONENT devel
		FILE LLVMJITConfig.cmake
		DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/LLVMJIT
		NAMESPACE LLVMJIT::)



# Set the non-compiled source files accumulated from the various library components as header-only,
# which includes the files in IDE projects, but doesn't compile them.
#target_sources(JIT PRIVATE ${WAVM_MONOLIB_NONCOMPILED_SOURCE_FILES})
#set_source_files_properties(${WAVM_MONOLIB_NONCOMPILED_SOURCE_FILES} PROPERTIES HEADER_FILE_ONLY TRUE)
## Create the LLVMJIT target.
#WAVM_ADD_LIB_COMPONENT(LLVMJIT
#	SOURCES ${Sources} ${PublicHeaders}
#	PUBLIC_LIB_COMPONENTS IR RuntimeABI
#	PRIVATE_LIB_COMPONENTS Logging Platform
#	PRIVATE_LIBS ${LLVM_LIBS}
#	PRIVATE_SYSTEM_INCLUDE_DIRECTORIES ${LLVM_INCLUDE_DIRS}
#	PRIVATE_DEFINITIONS ${LLVM_DEFINITIONS})
