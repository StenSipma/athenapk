message(STATUS 
    "-----------------------------------------------------------------------------------------------\n"
    "| Setup for the Habrock cluster at the High Performace Centre at the Rijksuniversiteit Groningen.\n"
    "| Specify 2 variables:\n"
    "| - HABROCK_NODE: the target node to compile for (gpu-A100, gpu-V100 or interactive-gpu)\n"
    "| - MACHINE_VARIANT: the build variant (cuda-mpi, cuda, cpu-mpi, cpu)\n"
    "-----------------------------------------------------------------------------------------------\n"
)

#### Modules that should be loaded:
## Python:
# $ module load Python/3.11.5-GCCcore-13.2.0
# $ mkdir -p $HOME/venvs
# $ python3 -m venv $HOME/venvs/athenapk-env
# $ source $HOME/venvs/athenapk-env/bin/activate
# $ pip install --upgrade pip
# $ pip install --upgrade wheel
# $ pip install numpy matplotlib scipy h5py unyt

# CUDA and HDF5 (with MPI):
# $ module load foss/2023b HDF5/1.14.3-gompi-2023b UCX-CUDA/1.15.0-GCCcore-13.2.0-CUDA-12.4.0

# Set the build variant:
# - Specify via the command line: -D MACHINE_VARIANT=<variant>
# - Via the environment variable: export MACHINE_VARIANT=<variant>
# - Default is 'cuda-mpi' (GPU build with MPI)
if (HABROCK_NODE)
    message(STATUS "HABROCK_NODE set from command line: ${HABROCK_NODE}")
elseif (DEFINED ENV{HABROCK_NODE})
    set(HABROCK_NODE $ENV{HABROCK_NODE} CACHE STRING "The target Habrock node to compile for")
else()
    message(FATAL_ERROR "HABROCK_NODE is not set. Please set it to one of the supported nodes (gpu1, interactive-gpu).")
endif()

######## Options: 
# GPU node 1: (gpu-A100)  (nodes=6)
# - Intel Xeon Platinum 8358 CPUs --> Kokkos_ARCH_ICX
# - Nvidia A100 GPU               --> Kokkos_ARCH_AMPERE80

# GPU node 2: (gpu-V100)  (nodes=19)
# - Intel Xeon Gold 6150 CPUs (SkyLake) --> Kokkos_ARCH_SKX
# - Nvidia V100 GPU                     --> Kokkos_ARCH_VOLTA70

# Interactive GPU nodes: (interactive-gpu)   (nodes=2)
# - 24 cores @ 2.4 GHz (two Intel Xeon Gold 6240R CPUs) --> Kokkos_ARCH_SKX (Cascade Lake = same as SkyLake)
# - 1 Nvidia L40s GPU accelerator card with 48GB RAM    --> Kokkos_ARCH_ADA89
#
# NOTE: the single and multi-node Habrock nodes are identical so can be the same compile
#       target.

# CPU node for multi-node jobs (cpu-multi)   (nodes=48)
#    128 cores @ 2.45 GHz (two AMD 7763 CPUs) --> Kokkos_ARCH_ZEN3 (Zen 3 (Milan))
#
# CPU node for single-node jobs (cpu-single) (nodes=84) 
#    128 cores @ 2.45 GHz (two AMD 7763 CPUs) --> Kokkos_ARCH_ZEN3 (Zen 3 (Milan))
################

# Set the build variant:
# - Specify via the command line: -D MACHINE_VARIANT=<variant>
# - Via the environment variable: export MACHINE_VARIANT=<variant>
# - Default is 'cuda-mpi' (GPU build with MPI)
## Options
# - cuda:     build with CUDA only
# - cuda-mpi: build with CUDA and MPI
# - cpu-mpi:  build with CPU and MPI
# - cpu:      build with CPU only
if (MACHINE_VARIANT)
    message(STATUS "MACHINE_VARIANT set from command line: ${MACHINE_VARIANT}")
elseif (DEFINED ENV{MACHINE_VARIANT})
    set(MACHINE_VARIANT $ENV{MACHINE_VARIANT} CACHE STRING "The build variant")
else()
    message(WARNING "MACHINE_VARIANT is not set. Defaulting to 'cuda-mpi'")
    set(MACHINE_VARIANT "cuda-mpi" CACHE STRING "GPU build with MPI")
endif()

set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Default release build")

## Set the CPU architecture flags based on the selected node
if (${HABROCK_NODE} STREQUAL "gpu-A100")
    message(STATUS "Compiling for Habrock GPU (gpu-A100)")
    set(Kokkos_ARCH_ICX ON CACHE BOOL "CPU architecture")

elseif (${HABROCK_NODE} STREQUAL "gpu-V100")
    message(STATUS "Compiling for Habrock GPU (gpu-V100)")
    set(Kokkos_ARCH_SKX ON CACHE BOOL "CPU architecture")

elseif (${HABROCK_NODE} STREQUAL "interactive-gpu")
    message(STATUS "Compiling for Habrock interactive GPU node (interactive-gpu)")
    set(Kokkos_ARCH_SKX ON CACHE BOOL "CPU architecture")

elseif (${HABROCK_NODE} STREQUAL "cpu-multi")
    message(STATUS "Compiling for Habrock CPU multi-node (cpu-multi)")
    set(Kokkos_ARCH_ZEN3 ON CACHE BOOL "CPU architecture")

elseif (${HABROCK_NODE} STREQUAL "cpu-single")
    message(STATUS "Compiling for Habrock CPU single-node (cpu-single)")
    set(Kokkos_ARCH_ZEN3 ON CACHE BOOL "CPU architecture")

else()
    message(FATAL_ERROR "Unknown HABROCK_NODE: ${HABROCK_NODE}")
endif()


if (${MACHINE_VARIANT} MATCHES "cuda")
    if (NOT ${HABROCK_NODE} MATCHES "gpu")
        message(FATAL_ERROR "CUDA build selected but HABROCK_NODE is not a GPU node: ${HABROCK_NODE}")
    endif()

    # Set the GPU architecture flags based on the selected node
    if (${HABROCK_NODE} STREQUAL "gpu-A100")
        set(Kokkos_ARCH_AMPERE80 ON CACHE BOOL "GPU architecture")
    elseif (${HABROCK_NODE} STREQUAL "gpu-V100")
        set(Kokkos_ARCH_VOLTA70 ON CACHE BOOL "GPU architecture")
    elseif (${HABROCK_NODE} STREQUAL "interactive-gpu")
        set(Kokkos_ARCH_ADA89 ON CACHE BOOL "GPU architecture")
    else()
        message(FATAL_ERROR "Unknown HABROCK_NODE: ${HABROCK_NODE}")
    endif()

    set(Kokkos_ENABLE_CUDA ON CACHE BOOL "Enable Cuda")
    set(CMAKE_CXX_COMPILER ${CMAKE_CURRENT_SOURCE_DIR}/external/Kokkos/bin/nvcc_wrapper CACHE STRING "Use nvcc_wrapper")
else()
    if (${HABROCK_NODE} MATCHES "gpu")
        message(WARNING "CPU build selected but HABROCK_NODE is a GPU node: ${HABROCK_NODE}, are you sure?")
    endif()

    set(CMAKE_CXX_COMPILER g++ CACHE STRING "Use g++")

    # TODO: check if this is actually needed...
    set(CMAKE_CXX_FLAGS "-fopenmp-simd -fprefetch-loop-arrays" CACHE STRING "Default opt flags")
    # Fast math causes issues due to 'proper' math checks with NaN's, so do not use this
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

    # TODO: check the below options, probably not needed anymore
    # Use a single resource set on a node that includes all cores and GPUs.
    # GPUs are automatically assigned round robin when run with more than one rank.
    # list(APPEND TEST_MPIOPTS "-n" "1" "-g" "6" "-c" "42" "-r" "1" "-d" "packed" "-b" "packed:7" "--smpiargs='-gpu'")
else()
  set(PARTHENON_DISABLE_MPI ON CACHE BOOL "Disable MPI")
endif()
