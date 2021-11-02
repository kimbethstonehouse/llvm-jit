#----------------------------------------------------------------
# Generated CMake target import file.
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "LLVMJIT::LLVMJIT" for configuration ""
set_property(TARGET LLVMJIT::LLVMJIT APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(LLVMJIT::LLVMJIT PROPERTIES
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/libLLVMJIT.so"
  IMPORTED_SONAME_NOCONFIG "libLLVMJIT.so"
  )

list(APPEND _IMPORT_CHECK_TARGETS LLVMJIT::LLVMJIT )
list(APPEND _IMPORT_CHECK_FILES_FOR_LLVMJIT::LLVMJIT "${_IMPORT_PREFIX}/lib/libLLVMJIT.so" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
