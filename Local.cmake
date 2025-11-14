message(STATUS "WIP machine config file for my local laptop.\n"
)

# common options
# set(Kokkos_ARCH_SPR ON CACHE BOOL "CPU architecture")
set(Kokkos_ARCH_NATIVE ON CACHE BOOL "CPU architecture")
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Default release build")
set(MACHINE_VARIANT "cpu-mpi" CACHE STRING "Default build for just CPU")
# Options for above
# - cuda: build with CUDA only
# - cuda-mpi: build with CUDA and MPI
# - cpu-mpi: build with CPU and MPI
# - cpu: build with CPU only

# variants
if (${MACHINE_VARIANT} MATCHES "cuda")
    set(Kokkos_ARCH_PASCAL61 ON CACHE BOOL "GPU architecture") # For my own GPU
  set(Kokkos_ENABLE_CUDA ON CACHE BOOL "Enable Cuda")
  set(CMAKE_CXX_COMPILER ${CMAKE_CURRENT_SOURCE_DIR}/external/Kokkos/bin/nvcc_wrapper CACHE STRING "Use nvcc_wrapper")
else()
  set(CMAKE_CXX_COMPILER g++ CACHE STRING "Use g++")
  set(CMAKE_CXX_FLAGS "-fopenmp-simd -fprefetch-loop-arrays" CACHE STRING "Default opt flags")
  # set(CMAKE_CXX_FLAGS "-fopenmp-simd -ffast-math -fprefetch-loop-arrays" CACHE STRING "Default opt flags")
endif()

# Setting launcher options independent of parallel or serial test as the launcher always
# needs to be called from the batch node (so that the tests are actually run on the
# compute nodes.

# TODO: check if the below flags work for my system...
set(TEST_MPIEXEC mpirun CACHE STRING "Command to launch MPI applications")
set(TEST_NUMPROC_FLAG "-np" CACHE STRING "Flag to set number of processes")
# set(NUM_GPU_DEVICES_PER_NODE "6" CACHE STRING "6x V100 per node")
set(PARTHENON_ENABLE_GPU_MPI_CHECKS OFF CACHE BOOL "Disable check by default")

if (${MACHINE_VARIANT} MATCHES "mpi")
    # set(PARTHENON_DISABLE_HDF5 ON CACHE BOOL "Disable HDF5 (does not work for parallel)")

  # Use a single resource set on a node that includes all cores and GPUs.
  # GPUs are automatically assigned round robin when run with more than one rank.
  list(APPEND TEST_MPIOPTS "-n" "1" "-g" "6" "-c" "42" "-r" "1" "-d" "packed" "-b" "packed:7" "--smpiargs='-gpu'")
else()
  set(PARTHENON_DISABLE_MPI ON CACHE BOOL "Disable MPI")
endif()
