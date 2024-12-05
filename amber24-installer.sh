#!/usr/bin/env bash

# MIT License
# 
# Copyright (c) 2024 Bundit Boonyarit
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -euo pipefail

# Default build type variables
BUILD_MPI=FALSE
BUILD_CUDA=FALSE
INSTALL_PREFIX="${HOME}/apps/amber24"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -cpu           Build Amber24 and AmberTools24 with serial CPU version"
    echo "  -gpu           Build Amber24 and AmberTools24 with serial GPU version"
    echo "  -mpi_cpu       Build Amber24 and AmberTools24 with parallel (MPI) CPU version"
    echo "  -mpi_gpu       Build Amber24 and AmberTools24 with parallel (MPI) GPU version"
    echo "  -path_install  Specify the installation prefix (default: ${INSTALL_PREFIX})"
    echo "  -h             Display this help message"
    echo
    echo "Example: $0 -gpu -path_install /opt/amber24"
    exit 1
}

# Parse command-line arguments
CPU_FLAG_SET=0
GPU_FLAG_SET=0
MPI_CPU_FLAG_SET=0
MPI_GPU_FLAG_SET=0

while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
        -cpu)
            CPU_FLAG_SET=1
            shift
            ;;
        -gpu)
            GPU_FLAG_SET=1
            shift
            ;;
        -mpi_cpu)
            MPI_CPU_FLAG_SET=1
            shift
            ;;
        -mpi_gpu)
            MPI_GPU_FLAG_SET=1
            shift
            ;;
        -path_install)
            if [[ $# -lt 2 ]]; then
                echo "Error: Missing argument for -path_install."
                usage
            fi
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

TOTAL_FLAGS=$((CPU_FLAG_SET + GPU_FLAG_SET + MPI_CPU_FLAG_SET + MPI_GPU_FLAG_SET))
if [[ $TOTAL_FLAGS -ne 1 ]]; then
    echo "Error: Please specify exactly one build option (-cpu, -gpu, -mpi_cpu, or -mpi_gpu)."
    usage
fi

# Determine build configuration
if [[ $CPU_FLAG_SET -eq 1 ]]; then
    BUILD_MPI=FALSE
    BUILD_CUDA=FALSE
elif [[ $GPU_FLAG_SET -eq 1 ]]; then
    BUILD_MPI=FALSE
    BUILD_CUDA=TRUE
elif [[ $MPI_CPU_FLAG_SET -eq 1 ]]; then
    BUILD_MPI=TRUE
    BUILD_CUDA=FALSE
elif [[ $MPI_GPU_FLAG_SET -eq 1 ]]; then
    BUILD_MPI=TRUE
    BUILD_CUDA=TRUE
fi

# Function to run cmake and make
build_amber() {
    local mpi=$1
    local cuda=$2
    local prefix=$3

    cd build || { echo "Error: amber24_src/build directory not found."; exit 1; }

	# If CMakeFiles exist, clean up before re-configuring
    if [ -d "CMakeFiles" ]; then
        echo "CMakeFiles folder found. Running 'make clean'..."
        make clean
    fi

    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DCOMPILER=GNU \
        -DMPI="$mpi" \
        -DCUDA="$cuda" \
        -DINSTALL_TESTS=TRUE \
        -DDOWNLOAD_MINICONDA=TRUE

    make -j"$(nproc)" && make install
}

# Main installation steps

# Check if Miniforge3 is already installed
if [ -d "./miniforge3" ]; then
    echo "miniforge3 directory already exists. Skipping installation of Miniforge3."
    source ./miniforge3/bin/activate
    set +u
    conda activate amber-installer
else
    # Download and install Miniforge3 and amber-installer environment if not present
    MINIFORGE_INSTALLER="Miniforge3-$(uname)-$(uname -m).sh"
    if [ ! -f "$MINIFORGE_INSTALLER" ]; then
        curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/$MINIFORGE_INSTALLER"
    fi
    bash "$MINIFORGE_INSTALLER" -b -p ./miniforge3
    source ./miniforge3/bin/activate
    
    # Install amber-installer environment
	conda env create -f env.yml
	set +u
	conda activate amber-installer
fi

# Check if the Amber tar files exist
if [ ! -f "AmberTools24.tar.bz2" ]; then
    echo "Error: AmberTools24.tar.bz2 not found in the current directory."
    exit 1
fi

if [ ! -f "Amber24.tar.bz2" ]; then
    echo "Error: Amber24.tar.bz2 not found in the current directory."
    exit 1
fi

# Extract Amber24 and AmberTools24 packages if not already extracted
if [ ! -d "amber24_src" ]; then
    tar xvfj AmberTools24.tar.bz2
    tar xvfj Amber24.tar.bz2
fi

# Update Amber
cd amber24_src
./update_amber --update

# Fix QUICK CMakeLists due to mpi.h issue
# Credit: https://github.com/merzlab/QUICK/issues/343
quick_cmake_path="AmberTools/src/quick/CMakeLists.txt"
sed -i '/set(CMAKE_C_FLAGS "")/s/^/# /' "$quick_cmake_path"
sed -i '/set(CMAKE_CXX_FLAGS "")/s/^/# /' "$quick_cmake_path"
sed -i '/set(CMAKE_Fortran_FLAGS "")/s/^/# /' "$quick_cmake_path"

# Create build directory if it does not exist
mkdir -p build

# Build Amber with the chosen configuration
echo "Building Amber with MPI=${BUILD_MPI}, CUDA=${BUILD_CUDA}, INSTALL_PREFIX=${INSTALL_PREFIX}..."
build_amber "${BUILD_MPI}" "${BUILD_CUDA}" "${INSTALL_PREFIX}"

# Construct a human-readable build configuration message
build_config="serial CPU"
if [[ "${BUILD_MPI}" == "TRUE" && "${BUILD_CUDA}" == "TRUE" ]]; then
    build_config="parallel GPU"
elif [[ "${BUILD_MPI}" == "TRUE" && "${BUILD_CUDA}" == "FALSE" ]]; then
    build_config="parallel CPU"
elif [[ "${BUILD_MPI}" == "FALSE" && "${BUILD_CUDA}" == "TRUE" ]]; then
    build_config="serial GPU"
fi

echo "Amber24 and AmberTools24 (${build_config}) installation completed successfully!"


