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

set -euo pipefail

# ----------------------------------------------------------------------------
# Colour codes
# ----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Colour

# ----------------------------------------------------------------------------
# Default installation prefixes (separated as requested)
# ----------------------------------------------------------------------------
INSTALL_PREFIX_AMBERTOOLS="${HOME}/ambertools25"
INSTALL_PREFIX_PMEMD="${HOME}/pmemd24"

# ----------------------------------------------------------------------------
# Default build flags
# ----------------------------------------------------------------------------
BUILD_MPI=false
BUILD_CUDA=false
BUILD_AMBERTOOLS=false
BUILD_PMEMD=false
NPROC=$(nproc)

# ----------------------------------------------------------------------------
# Helper: usage message
# ----------------------------------------------------------------------------
usage() {
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}\n"
    echo "Options:"
    echo "  -cpu                Build serial CPU version"
    echo "  -gpu                Build serial GPU version with CUDA"
    echo "  -mpi_cpu            Build MPI‑parallel CPU version"
    echo "  -mpi_gpu            Build MPI‑parallel GPU version (MPI + CUDA)"
    echo "  -ambertools         Build AmberTools25"
    echo "  -pmemd              Build PMEMD24"
    echo "  -path_ambertools <path>   Override AmberTools25 installation prefix"
    echo "  -path_pmemd <path>        Override PMEMD24 installation prefix"
    echo "  -nproc <n>               Number of CPU cores for compilation (default: all)"
    echo "  -h | --help          Show this help message and exit"
    exit 1
}

# ----------------------------------------------------------------------------
# CLI argument parsing
# ----------------------------------------------------------------------------
CPU_FLAG_SET=0
GPU_FLAG_SET=0
MPI_CPU_FLAG_SET=0
MPI_GPU_FLAG_SET=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -cpu)       CPU_FLAG_SET=1;    shift;;
        -gpu)       GPU_FLAG_SET=1;    shift;;
        -mpi_cpu)   MPI_CPU_FLAG_SET=1;shift;;
        -mpi_gpu)   MPI_GPU_FLAG_SET=1;shift;;
        -ambertools) BUILD_AMBERTOOLS=true; shift;;
        -pmemd)      BUILD_PMEMD=true;  shift;;
        -path_ambertools)
            [[ $# -lt 2 ]] && { echo -e "${RED}Error: -path_ambertools requires an argument.${NC}"; usage; }
            INSTALL_PREFIX_AMBERTOOLS="$2"; shift 2;;
        -path_pmemd)
            [[ $# -lt 2 ]] && { echo -e "${RED}Error: -path_pmemd requires an argument.${NC}"; usage; }
            INSTALL_PREFIX_PMEMD="$2"; shift 2;;
        -nproc)
            [[ $# -lt 2 ]] && { echo -e "${RED}Error: -nproc requires an argument.${NC}"; usage; }
            NPROC="$2"; shift 2;;
        -h|--help)  usage;;
        *)          echo -e "${RED}Unknown argument: $1${NC}"; usage;;
    esac
done

TOTAL_FLAGS=$((CPU_FLAG_SET + GPU_FLAG_SET + MPI_CPU_FLAG_SET + MPI_GPU_FLAG_SET))
if [[ $TOTAL_FLAGS -ne 1 ]]; then
    echo -e "${RED}Error: choose exactly one build type (-cpu, -gpu, -mpi_cpu, -mpi_gpu).${NC}"
    usage
fi

if [[ "${BUILD_AMBERTOOLS}" = false && "${BUILD_PMEMD}" = false ]]; then
    echo -e "${RED}Error: specify at least one of -ambertools or -pmemd.${NC}"
    usage
fi

# ----------------------------------------------------------------------------
# Configure build type
# ----------------------------------------------------------------------------
if   [[ $CPU_FLAG_SET -eq 1 ]];      then BUILD_MPI=false; BUILD_CUDA=false;
elif [[ $GPU_FLAG_SET -eq 1 ]];      then BUILD_MPI=false; BUILD_CUDA=true;
elif [[ $MPI_CPU_FLAG_SET -eq 1 ]];  then BUILD_MPI=true;  BUILD_CUDA=false;
elif [[ $MPI_GPU_FLAG_SET -eq 1 ]];  then BUILD_MPI=true;  BUILD_CUDA=true;
fi

# ----------------------------------------------------------------------------
# Environment‑modules handling (optional)
# ----------------------------------------------------------------------------
if command -v module &>/dev/null && [[ -n "${LMOD_CMD:-}" ]]; then
    echo -e "${BLUE}Detected Lmod environment — purging loaded modules...${NC}"
    module purge
fi

# ----------------------------------------------------------------------------
# Conda bootstrap (local Miniforge3) — unchanged from original script
# ----------------------------------------------------------------------------
if [[ -d ./miniforge3 ]]; then
    echo -e "${BLUE}Activating existing conda environment...${NC}"
    source ./miniforge3/bin/activate
    set +u
    conda activate amber-installer
else
    MINIFORGE_INSTALLER="Miniforge3-$(uname)-$(uname -m).sh"
    [[ -f "$MINIFORGE_INSTALLER" ]] || curl -LO "https://github.com/conda-forge/miniforge/releases/latest/download/$MINIFORGE_INSTALLER"
    bash "$MINIFORGE_INSTALLER" -b -p ./miniforge3
    source ./miniforge3/bin/activate
    echo -e "${BLUE}Creating conda environment 'amber-installer'...${NC}"
    conda env create -f env.yml
    set +u
    conda activate amber-installer
fi

# ----------------------------------------------------------------------------
# AmberTools25 build
# ----------------------------------------------------------------------------
if [[ "${BUILD_AMBERTOOLS}" = true ]]; then
    [[ -f ambertools25.tar.bz2 ]] || {
        echo -e "${RED}Error: ambertools25.tar.bz2 not found.${NC}\n${YELLOW}Download it from https://ambermd.org/GetAmber.php${NC}";
        exit 1;
    }

    echo -e "${BLUE}Extracting AmberTools25...${NC}"
    [[ -d ambertools25_src ]] || tar xvjf ambertools25.tar.bz2

    pushd ambertools25_src > /dev/null
      ./update_amber --update

      # QUICK fix for mpi.h CMake flags (see original notes)
      sed -i '/set(CMAKE_C_FLAGS "")/s/^/# /'   AmberTools/src/quick/CMakeLists.txt
      sed -i '/set(CMAKE_CXX_FLAGS "")/s/^/# /' AmberTools/src/quick/CMakeLists.txt
      sed -i '/set(CMAKE_Fortran_FLAGS "")/s/^/# /' AmberTools/src/quick/CMakeLists.txt

      mkdir -p build && cd build

      echo -e "${BLUE}Configuring AmberTools25 (MPI=${BUILD_MPI}, CUDA=${BUILD_CUDA}, PREFIX=${INSTALL_PREFIX_AMBERTOOLS})...${NC}"

      [[ -d CMakeFiles ]] && { echo "CMakeFiles detected — running make clean"; make clean; }

      cmake .. \
          -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX_AMBERTOOLS}" \
          -DCOMPILER=GNU \
          -DMPI="${BUILD_MPI}" \
          -DCUDA="${BUILD_CUDA}" \
          -DINSTALL_TESTS=TRUE \
          -DDOWNLOAD_MINICONDA=TRUE

      echo -e "${BLUE}Building AmberTools25 with ${NPROC} cores...${NC}"
      make -j"${NPROC}" && make install
    popd > /dev/null
    echo -e "${GREEN}AmberTools25 installed to ${INSTALL_PREFIX_AMBERTOOLS}${NC}"
fi

# ----------------------------------------------------------------------------
# PMEMD24 build
# ----------------------------------------------------------------------------
if [[ "${BUILD_PMEMD}" = true ]]; then
    [[ -f pmemd24.tar.bz2 ]] || {
        echo -e "${RED}Error: pmemd24.tar.bz2 not found.${NC}\n${YELLOW}Download it from https://ambermd.org/GetAmber.php${NC}";
        exit 1;
    }

    echo -e "${BLUE}Extracting PMEMD24...${NC}"
    [[ -d pmemd24_src ]] || tar xvjf pmemd24.tar.bz2

    pushd pmemd24_src > /dev/null
      ./update_amber --update

      mkdir -p build && cd build

      echo -e "${BLUE}Configuring PMEMD24 (MPI=${BUILD_MPI}, CUDA=${BUILD_CUDA}, PREFIX=${INSTALL_PREFIX_PMEMD})...${NC}"

      [[ -d CMakeFiles ]] && { echo "CMakeFiles detected — running make clean"; make clean; }

      cmake .. \
          -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX_PMEMD}" \
          -DCOMPILER=GNU \
          -DMPI="${BUILD_MPI}" \
          -DCUDA="${BUILD_CUDA}" \
          -DDOWNLOAD_MINICONDA=FALSE \
          -DINSTALL_TESTS=TRUE \
          -DBUILD_PYTHON=FALSE \
          -DBUILD_PERL=FALSE \
          -DBUILD_GUI=FALSE \
          -DPMEMD_ONLY=TRUE \
          -DCHECK_UPDATES=FALSE

      echo -e "${BLUE}Building PMEMD24 with ${NPROC} cores...${NC}"
      make -j"${NPROC}" && make install
    popd > /dev/null
    echo -e "${GREEN}PMEMD24 installed to ${INSTALL_PREFIX_PMEMD}${NC}"
fi

# ----------------------------------------------------------------------------
# Completion message
# ----------------------------------------------------------------------------
if [[ "${BUILD_AMBERTOOLS}" = true && "${BUILD_PMEMD}" = true ]]; then
    echo -e "${GREEN}Both AmberTools25 and PMEMD24 installations completed successfully.${NC}"
elif [[ "${BUILD_AMBERTOOLS}" = true ]]; then
    echo -e "${GREEN}AmberTools25 installation completed successfully.${NC}"
else
    echo -e "${GREEN}PMEMD24 installation completed successfully.${NC}"
fi
