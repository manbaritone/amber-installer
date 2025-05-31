#!/usr/bin/env bash

# MIT License
# 
# Copyright (c) 2025 Bundit Boonyarit
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

#!/usr/bin/env bash

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Purge environment modules if Lmod is available
if command -v module &>/dev/null && [ -n "${LMOD_CMD:-}" ]; then
    echo -e "${BLUE}Detected Lmod environment. Purging loaded modules...${NC}"
    module purge
fi

# Default build flags
BUILD_MPI=FALSE
BUILD_CUDA=FALSE
INSTALL_PREFIX="${HOME}/amber25"
BUILD_AMBERTOOLS=false
BUILD_PMEMD=false
NPROC=$(nproc)

usage() {
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
    echo
    echo "Options:"
    echo "  -cpu             Build with serial CPU version"
    echo "  -gpu             Build with serial GPU version"
    echo "  -mpi_cpu         Build with parallel (MPI) CPU version"
    echo "  -mpi_gpu         Build with parallel (MPI) GPU version"
    echo "  -ambertools      Build AmberTools25"
    echo "  -pmemd           Build PMEMD24"
    echo "  -path_install    Installation prefix (default: \$HOME/amber25)"
    echo "  -nproc <n>       Set number of CPU cores for compilation (default: all cores)"
    echo "  -h               Show this help message"
    exit 1
}

# Parse command-line arguments
CPU_FLAG_SET=0
GPU_FLAG_SET=0
MPI_CPU_FLAG_SET=0
MPI_GPU_FLAG_SET=0

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -cpu) CPU_FLAG_SET=1; shift;;
        -gpu) GPU_FLAG_SET=1; shift;;
        -mpi_cpu) MPI_CPU_FLAG_SET=1; shift;;
        -mpi_gpu) MPI_GPU_FLAG_SET=1; shift;;
        -ambertools) BUILD_AMBERTOOLS=true; shift;;
        -pmemd) BUILD_PMEMD=true; shift;;
        -path_install)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}Error: -path_install requires a path for installation.${NC}"
                usage
            fi
            INSTALL_PREFIX="$2"
            shift 2;;
        -nproc)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}Error: -nproc requires a number${NC}"
                usage
            fi
            NPROC="$2"
            shift 2;;
        -h|--help) usage;;
        *) echo -e "${RED}Unknown argument: $1${NC}"; usage;;
    esac
done

TOTAL_FLAGS=$((CPU_FLAG_SET + GPU_FLAG_SET + MPI_CPU_FLAG_SET + MPI_GPU_FLAG_SET))
if [[ $TOTAL_FLAGS -ne 1 ]]; then
    echo -e "${RED}Error: Choose one build type (-cpu, -gpu, -mpi_cpu, -mpi_gpu)${NC}"
    usage
fi

if [[ "$BUILD_AMBERTOOLS" = false && "$BUILD_PMEMD" = false ]]; then
    echo -e "${RED}Error: Choose at least one of -ambertools or -pmemd${NC}"
    usage
fi

# Set build configuration
if [[ $CPU_FLAG_SET -eq 1 ]]; then
    BUILD_MPI=FALSE; BUILD_CUDA=FALSE
elif [[ $GPU_FLAG_SET -eq 1 ]]; then
    BUILD_MPI=FALSE; BUILD_CUDA=TRUE
elif [[ $MPI_CPU_FLAG_SET -eq 1 ]]; then
    BUILD_MPI=TRUE; BUILD_CUDA=FALSE
elif [[ $MPI_GPU_FLAG_SET -eq 1 ]]; then
    BUILD_MPI=TRUE; BUILD_CUDA=TRUE
fi

# Setup conda environment
# Check if Miniforge3 is already installed
if [ -d "./miniforge3" ]; then
    echo -e "${BLUE}Activating existing conda environment...${NC}"
    source ./miniforge3/bin/activate
    set +u
    conda activate amber-installer
else
    # Download and install Miniforge3 and amber-installer environment if not present
    MINIFORGE_INSTALLER="Miniforge3-$(uname)-$(uname -m).sh"
    [ -f "$MINIFORGE_INSTALLER" ] || curl -LO "https://github.com/conda-forge/miniforge/releases/latest/download/$MINIFORGE_INSTALLER"
    bash "$MINIFORGE_INSTALLER" -b -p ./miniforge3
    source ./miniforge3/bin/activate
    echo -e "${BLUE}Creating conda environment 'amber-installer'...${NC}"
    
    # Install amber-installer environment
    conda env create -f env.yml
    set +u
    conda activate amber-installer
fi

# AmberTools25 installation
# Check if the ambertools tar files exist
if [ "$BUILD_AMBERTOOLS" = true ]; then
    if [ ! -f "ambertools25.tar.bz2" ]; then
        echo -e "${RED}Error: ambertools25.tar.bz2 not found in the current directory.${NC}"
        echo -e "${YELLOW}Please download ambertools25.tar.bz2 file from https://ambermd.org/GetAmber.php${NC}"
        exit 1
    fi
    echo -e "${BLUE}Extracting AmberTools25...${NC}"
    [ -d "ambertools25_src" ] || tar xvjf ambertools25.tar.bz2
    
    # Update Amber
    cd ambertools25_src
    ./update_amber --update
    
    # Fix QUICK CMakeLists due to mpi.h issue
    # Credit: https://github.com/merzlab/QUICK/issues/343
    quick_cmake_path="AmberTools/src/quick/CMakeLists.txt"
    sed -i '/set(CMAKE_C_FLAGS "")/s/^/# /' "$quick_cmake_path"
    sed -i '/set(CMAKE_CXX_FLAGS "")/s/^/# /' "$quick_cmake_path"
    sed -i '/set(CMAKE_Fortran_FLAGS "")/s/^/# /' "$quick_cmake_path"
    
    # Create build directory if it does not exist
    mkdir -p build && cd build
    
    # Build AmberTools with the chosen configuration
    echo -e "${BLUE}Configuring AmberTools25 with MPI=${BUILD_MPI}, CUDA=${BUILD_CUDA}, INSTALL_PREFIX=${INSTALL_PREFIX}...${NC}"
    
    # If CMakeFiles exist, clean up before re-configuring
    if [ -d "CMakeFiles" ]; then
        echo "CMakeFiles folder found. Running 'make clean'..."
        make clean
    fi
    
    # Function to run cmake and make
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DCOMPILER=GNU \
        -DMPI="$BUILD_MPI" \
        -DCUDA="$BUILD_CUDA" \
        -DINSTALL_TESTS=TRUE \
        -DDOWNLOAD_MINICONDA=TRUE
    echo -e "${BLUE}Building AmberTools25 with $NPROC threads...${NC}"
    make -j"$NPROC" && make install
    cd ../..
    echo -e "${GREEN}AmberTools25 build complete.${NC}"
fi

# PMEMD24-only installation
# Check if the pmemd tar files exist
if [ "$BUILD_PMEMD" = true ]; then
    if [ ! -f "pmemd24.tar.bz2" ]; then
        echo -e "${RED}Error: pmemd24.tar.bz2 not found in the current directory.${NC}"
        echo -e "${YELLOW}Please download pmemd24.tar.bz2 file from https://ambermd.org/GetAmber.php${NC}"
        exit 1
    fi
    echo -e "${BLUE}Extracting PMEMD24...${NC}"
    [ -d "pmemd24_src" ] || tar xvjf pmemd24.tar.bz2
    
    # Update Amber
    cd pmemd24_src
    ./update_amber --update
    
    # Create build directory if it does not exist
    mkdir -p build && cd build
    
    echo -e "${BLUE}Configuring PMEMD24 with MPI=${BUILD_MPI}, CUDA=${BUILD_CUDA}, INSTALL_PREFIX=${INSTALL_PREFIX}...${NC}"
    
    # If CMakeFiles exist, clean up before re-configuring
    if [ -d "CMakeFiles" ]; then
        echo "CMakeFiles folder found. Running 'make clean'..."
        make clean
    fi
    
    # Function to run cmake and make
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DCOMPILER=GNU \
        -DMPI="$BUILD_MPI" \
        -DCUDA="$BUILD_CUDA" \
        -DDOWNLOAD_MINICONDA=FALSE \
        -DINSTALL_TESTS=TRUE \
        -DBUILD_PYTHON=FALSE \
        -DBUILD_PERL=FALSE \
        -DBUILD_GUI=FALSE \
        -DPMEMD_ONLY=TRUE \
        -DCHECK_UPDATES=FALSE
    echo -e "${BLUE}Building PMEMD24 with $NPROC threads...${NC}"
    make -j"$NPROC" && make install
    cd ../..
    echo -e "${GREEN}PMEMD24 build complete.${NC}"
fi

echo -e "${GREEN}Installation completed successfully at ${INSTALL_PREFIX}.${NC}"
