#!/usr/bin/env bash

# Script adapted from https://github.com/EESSI/filesystem-layer/pull/288

BASEDIR=$(dirname "$0")

# check that the `easybuild-jupyter-kernels` command is available
if ! command -v easybuild-jupyter-kernels &> /dev/null; then
    echo "easybuild-jupyter-kernels command not found..."
    exit 1
fi

function echo_green() {
    echo -e "\e[32m$1\e[0m"
}

function echo_yellow() {
    echo -e "\e[33m$1\e[0m"
}

function echo_red() {
    echo -e "\e[31m$1\e[0m"
}

function error() {
    echo_red "ERROR: $1" >&2
    exit 1
}

STACK_DIR="/cvmfs/software.eessi.io"
# get version directories from the STACK_DIR
EESSI_VERSIONS=($(find "${STACK_DIR}/versions" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort))
if [ ${#EESSI_VERSIONS[@]} -eq 0 ]; then
    error "No EESSI versions found in ${STACK_DIR}/versions"
fi
echo_yellow "Found EESSI versions: ${EESSI_VERSIONS[*]}"
STACK_BASE_DIR="${STACK_DIR}/versions/${EESSI_VERSIONS[0]}"
EB_JPT_CLI=$(command -v easybuild-jupyter-kernels)

# Create temporary directory for the kernels in this dir
TMPDIR=${1:-$(mktemp -d -t eessi_kernels_XXXX -p "${BASEDIR}")}
echo_yellow "Temporary directory for EESSI kernels: ${TMPDIR}"

source ${STACK_DIR}/versions/${EESSI_VERSIONS[0]}/init/lmod/bash
module --force purge

for version_dir in "${EESSI_VERSIONS[@]}"; do
    echo "Updating EESSI kernels for version: $version_dir"
    STACK_BASE_DIR="${STACK_DIR}/versions/${version_dir}"
    architectures=$(find ${STACK_BASE_DIR}/software/ -maxdepth 5 -type d -name modules -exec dirname {} \;)
    num_architectures=$(echo "$architectures" | wc -l)
    arch_count=0
    for archdir in $architectures; do
        arch_subdir=$(realpath --relative-to="${STACK_BASE_DIR}/software/linux" "${archdir}")
        export EESSI_SOFTWARE_SUBDIR_OVERRIDE="${arch_subdir}"
        echo "    -----------------------------------------------------------------------------------------------------------"
        echo_yellow "    Loading EESSI stack version ${version_dir} for architecture ${EESSI_SOFTWARE_SUBDIR_OVERRIDE}...  ($((++arch_count))/$num_architectures)"
        module load EESSI/${version_dir}
        
        ARCH_MODULEPATH="$MODULEPATH"
        ARCH_EPREFIX="$EESSI_EPREFIX"
        ARCH_LMOD_RC="$LMOD_RC"

        # Run using a viable architecture during `module load EESSI` to get compat layer binaries that works, but replace
        # the module loaded with the actual architecture we want to update the kernels for
        # NOTE: this assumes that the `module load` results do not rely on having the binaries for the proper architecture.
        module purge
        export EESSI_SOFTWARE_SUBDIR_OVERRIDE=""
        module load EESSI/${version_dir}
        MODULEPATH="${ARCH_MODULEPATH}"
        
        # Ensure the compat layer binaries are in the PATH in case the kernels uses them to run commands
        # Append them so that the correect binaries for the actual architecture are used first when running `module load``
        PREVIOUS_PATH="${PATH}"
        PREVIOUS_LMOD_RC="${LMOD_RC}"
        export LMOD_RC="${ARCH_LMOD_RC}"
        export PATH="${PATH}:${ARCH_EPREFIX}/bin:${ARCH_EPREFIX}/usr/bin"

        OUTDIR="${TMPDIR}/${arch_subdir}/kernels"
        mkdir -p "${OUTDIR}"

        export EB_JUPYTER_KERNEL_DISPLAY_PREFIX="EESSI/${version_dir} -"
        # --filter-paths: Only pickup kernels from directories that match the given regex pattern
        # --filter-env-paths: Filter PATH-like environment variables to only include directories that match the given
        #                     regex pattern (multiple --filter-env-paths imply OR logic)
        ${EB_JPT_CLI} store-kernels \
            --filter-paths "^${STACK_BASE_DIR}/software/linux/${arch_subdir}/" \
            --filter-env-paths "^${STACK_BASE_DIR}/software/linux/${arch_subdir}/" \
            --filter-env-paths "^${ARCH_EPREFIX}.*/bin$" \
            ${OUTDIR}

        # Restore the previous PATH so that `module purge` does not leave the manually added paths potentially causing
        # issues for the next architecture in the loop
        export LMOD_RC="${PREVIOUS_LMOD_RC}"
        export PATH="${PREVIOUS_PATH}"

        exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            echo_green "    Updated the Jupyter kernels for EESSI ${version_dir} - ARCH: ${archdir}."
        else
            error "    Failed to update the Jupyter kernels for EESSI ${version_dir} - ARCH: ${archdir}. Exit code: ${exit_code}"
        fi
    done
done

echo_green "All EESSI kernels have been updated successfully. The updated kernels are located in: ${TMPDIR}"
