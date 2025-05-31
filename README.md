# AMBER-Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

This repository provides a Bash script to install Amber and AmberTools for Linux with various build configurations (CPU/GPU and MPI/Non-MPI). The script also manages the Miniforge/Conda environment setup, ensuring a smooth and automated installation process.

## Features

- **Single-Flag Build Selection:** Choose one of the following build options:
  - `-cpu`: Serial CPU version
  - `-gpu`: Serial GPU version
  - `-mpi_cpu`: Parallel (MPI) CPU version
  - `-mpi_gpu`: Parallel (MPI) GPU version

- **Choose AmberTools or PMEMED:** Choose the installation type of AmberTools25 or PMEMD.
- 
- **Custom Installation Prefix:** Set the installation path with `-path_install <path>` (defaults to `$HOME/amber25`).

- **Automated Environment Setup:** Installs Miniforge3 if not already present. If `./miniforge3` directory exists, the script will use the existing Miniforge installation.

- **Set No. CPU Cores:** Set the number of CPU cores for the compilation process with `-nproc <n>` (default: all cores)
  
- **Conda Environment:** The script creates and activates a `conda` environment from `env.yml` (e.g., `amber-installer`) before building.

- **Patch for QUICK CMakeLists:** Automatically applies a patch to avoid issues with `mpi.h` in QUICK.

## Requirements

- **Files:**  
  - `env.yml` (Conda environment specification)  
  - `ambertools25.tar.bz2` and/or `pmemd24.tar.bz2` must be in the current directory (amber-installer folder).
    
    **Note:** Please download ambertools25.tar.bz2 and pmemd24.tar.bz2 from [https://ambermd.org/](https://ambermd.org/GetAmber.php)

- **Internet Connection:** Needed for downloading Miniforge3 if it's not already present.

- **Unix-like Environment:** The script is designed for Linux.

## Usage

1. **Clone this repository** (or download the script and required files):
   ```bash
   git clone https://github.com/manbaritone/amber-installer.git
   cd amber-installer
2. Ensure env.yml is present and that AmberTools24.tar.bz2 and Amber24.tar.bz2 are in the same directory as the script.
3. Run the script with the desired build option:
   ```bash
   bash amber25-installer.sh [OPTIONS]
   ```
   **Example for AMBER25**
   ```bash
   bash amber25-installer.sh -ambertools25 -gpu -path_install /opt/amber24
   ```
   ```bash
   bash amber25-installer.sh -pmemd24 -mpi_cpu -path_install /opt/amber24
   ```
   **Options**
   - `-cpu`: Build with serial CPU version.
   - `-gpu`: Build with serial GPU version.
   - `-mpi_cpu`: Build with parallel (MPI) CPU version.
   - `-mpi_gpu`: Build with parallel (MPI) GPU version.
   - `-ambertools25`: Build AmberTools25.
   - `-pmemd24`: Build PMEMD24.
   - `-path_install <path>`: Specify the installation prefix (default: ~/amber25).
   - `-nproc <n>`: Specify number of CPU cores for compilation (default: all cores).
   - `-h`: Display the help message.
   
     **Note:** Only one of the four build options (-cpu, -gpu, -mpi_cpu, or -mpi_gpu) can be specified at a time.

## Running Amber and AmberTools

Once you have successfully installed AmberTools and/or PMEMD using the installer script, you can run Amber programs by activating the conda environment and using the installed executables.

**Activate the Conda Environment**

After installation, an environment named `amber-installer` was created. To activate it, run:
```bash
source amber-installer/miniforge3/bin/activate
conda activate amber-installer
source path/to/amber_installation_folder/amber.sh
```

## License
This project is licensed under the MIT License. See the LICENSE file for details.
