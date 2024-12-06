# Amber-Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

This repository provides a Bash script to install Amber and AmberTools for Linux with various build configurations (CPU/GPU and MPI/Non-MPI). The script also manages the Miniforge/Conda environment setup, ensuring a smooth and automated installation process.

## Features

- **Single-Flag Build Selection:** Choose one of the following build options:
  - `-cpu`: Serial CPU version
  - `-gpu`: Serial GPU version
  - `-mpi_cpu`: Parallel (MPI) CPU version
  - `-mpi_gpu`: Parallel (MPI) GPU version
  
- **Custom Installation Prefix:** Set the installation path with `-path_install <path>` (defaults to `~/apps/amber24`).

- **Automated Environment Setup:** Installs Miniforge3 if not already present. If `./miniforge3` directory exists, the script will use the existing Miniforge installation.

- **Conda Environment:** The script creates and activates a `conda` environment from `env.yml` (e.g., `amber-installer`) before building.

- **Patch for QUICK CMakeLists:** Automatically applies a patch to avoid issues with `mpi.h` in QUICK.

## Requirements

- **Files:**  
  - `env.yml` (Conda environment specification)  
  - `AmberTools24.tar.bz2` and `Amber24.tar.bz2` must be in the current directory (amber-installer folder).
    
    **Note:** Please download AmberTools24.tar.bz2 and Amber24.tar.bz2 from https://ambermd.org/

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
   bash amber24-installer.sh [OPTIONS]
   ```
   **Example**
   ```bash
   bash amber24-installer.sh -gpu -path_install /opt/amber24
   ```
   **Options**
   - `-cpu`: Build Amber with serial CPU only.
   - `-gpu`: Build Amber with serial GPU support.
   - `-mpi_cpu`: Build Amber with MPI-enabled CPU support.
   - `-mpi_gpu`: Build Amber with MPI-enabled GPU support.
   - `-path_install <path>`: Specify the installation prefix (default: ~/apps/amber24).
   - `-h`: Display the help message.
   
     **Note:** Only one of the four build options (-cpu, -gpu, -mpi_cpu, or -mpi_gpu) can be specified at a time.

## Running Amber and AmberTools

Once you have successfully installed Amber24 and AmberTools24 using the installer script, you can run Amber programs by activating the conda environment and using the installed executables.

**Activate the Conda Environment**

After installation, an environment named `amber-installer` was created. To activate it, run:
```bash
source amber-installer/miniforge3/bin/activate
conda activate amber-installer
source path/to/amber_installation_folder/amber.sh
```

## License
This project is licensed under the MIT License. See the LICENSE file for details.
