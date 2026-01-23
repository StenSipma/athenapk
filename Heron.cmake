message(STATUS 
"---------------------------------------------------------------------------------------\n"
"| Running setup for the Heron cluster at the Kapteyn Astronomical Institute.\n"
"|\n"
"| Specify 1 variable:\n"
"| - MACHINE_VARIANT: the build variant (cuda-mpi, cuda, cpu-mpi, cpu)\n"
"|\n"
"| !!! Make sure you have the proper modules loaded before compiling !!!\n"
"| For the CPU nodes: openmpi,hdf5\n"
"| For the GPU nodes: openmpi,hdf5,cuda\n"
"---------------------------------------------------------------------------------------\n"
)

set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Default release build")

#### If you want to run tests, also enable a virtual environemnt:
## Python virtual environment (only if you want to run tests!)
# $ module load Python/3.11.5-GCCcore-13.2.0
# $ mkdir -p $HOME/venvs
# $ python3 -m venv $HOME/venvs/athenapk-env
# $ source $HOME/venvs/athenapk-env/bin/activate
# $ pip install --upgrade pip
# $ pip install --upgrade wheel
# $ pip install numpy matplotlib scipy h5py unyt


# Set the build variant:
# - Specify via the command line: -D MACHINE_VARIANT=<variant>
# - Via the environment variable: export MACHINE_VARIANT=<variant>
# - Default is 'cpu-mpi' (CPU build with MPI)
## Options
# - cuda:     build with CUDA only
# - cuda-mpi: build with CUDA and MPI
# - cpu-mpi:  build with CPU and MPI
# - cpu:      build with CPU only
if (MACHINE_VARIANT)
    message(STATUS "MACHINE_VARIANT set from command line: ${MACHINE_VARIANT}")
elseif (DEFINED ENV{MACHINE_VARIANT})
    set(MACHINE_VARIANT $ENV{MACHINE_VARIANT} CACHE STRING "The build variant")
    message(STATUS "MACHINE_VARIANT set from environment: ${MACHINE_VARIANT}")
else()
    set(MACHINE_VARIANT "cpu-mpi" CACHE STRING "CPU build with MPI")
    message(STATUS "MACHINE_VARIANT is not set. Defaulting to ${MACHINE_VARIANT}")
endif()

# CPU architecture is always the same
set(Kokkos_ARCH_ZEN3 ON CACHE BOOL "CPU architecture")

if (${MACHINE_VARIANT} MATCHES "gpu")
    message(STATUS "Compiling with the GPU target")
    set(Kokkos_ARCH_ADA89 ON CACHE BOOL "GPU architecture")
    set(Kokkos_ENABLE_CUDA ON CACHE BOOL "Enable Cuda")
    set(CMAKE_CXX_COMPILER ${CMAKE_CURRENT_SOURCE_DIR}/external/Kokkos/bin/nvcc_wrapper CACHE STRING "Use nvcc_wrapper")

elseif (${MACHINE_VARIANT} MATCHES "cpu")
    message(STATUS "Compiling with the CPU target")
    set(CMAKE_CXX_COMPILER g++ CACHE STRING "Use g++")

    # TODO: check if this is actually needed...
    set(CMAKE_CXX_FLAGS "-fopenmp-simd -fprefetch-loop-arrays" CACHE STRING "Default opt flags")
else()
    message(FATAL_ERROR "Unknown MACHINE_VARIANT: ${MACHINE_VARIANT}")
endif()


# Setting launcher options independent of parallel or serial test as the launcher always
# needs to be called from the batch node (so that the tests are actually run on the
# compute nodes.

# TODO: check if the below flags work for my system...
# set(TEST_MPIEXEC mpirun CACHE STRING "Command to launch MPI applications")
# set(TEST_NUMPROC_FLAG "-np" CACHE STRING "Flag to set number of processes")
# set(NUM_GPU_DEVICES_PER_NODE "6" CACHE STRING "6x V100 per node")
# set(PARTHENON_ENABLE_GPU_MPI_CHECKS OFF CACHE BOOL "Disable check by default")
if (${MACHINE_VARIANT} MATCHES "mpi")
    # set(PARTHENON_DISABLE_HDF5 ON CACHE BOOL "Disable HDF5 (does not work for parallel)")

    # TODO: check the below options, probably not needed anymore
    # Use a single resource set on a node that includes all cores and GPUs.
    # GPUs are automatically assigned round robin when run with more than one rank.
    # list(APPEND TEST_MPIOPTS "-n" "1" "-g" "6" "-c" "42" "-r" "1" "-d" "packed" "-b" "packed:7" "--smpiargs='-gpu'")
else()
  set(PARTHENON_DISABLE_MPI ON CACHE BOOL "Disable MPI")
endif()


