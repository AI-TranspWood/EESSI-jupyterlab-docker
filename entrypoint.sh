#!/bin/bash

USER=eessi-user

export REQUESTED_EESSI_VERSION=${REQUESTED_EESSI_VERSION:-2023.06}

# Clean up any existing port files from previous runs to avoid using stale port numbers before the new one are updated
rm /home/${USER}/flask_port.env /home/${USER}/jupyter_port.env 2>/dev/null || true

# Needed to avoid `Failed to initialize loader socket` error
# Needs to be inside the entrypoint script in case of volume mounts
mkdir -p /cvmfs-cache
chown -R cvmfs:cvmfs /cvmfs-cache

# Ensure Jupyter config directory exists and is owned by the specified user
mkdir -p /home/${USER}/.jupyter/lab/workspaces
mkdir -p /home/${USER}/.jupyter/lab/user-settings/@jupyterlab/docmanager-extension
cat > /home/${USER}/.jupyter/lab/user-settings/@jupyterlab/docmanager-extension/plugin.jupyterlab-settings << EOF
{
  "defaultViewers": {
    "json": "Editor"
  }
}
EOF

BASHRC="/home/${USER}/.bashrc"
if [ -z "`grep 'export PATH="/opt/jupyter-env/bin' ${BASHRC}`" ]; then
    echo -e '\n# EESSI CVMFS module initialization' >> ${BASHRC}
    echo "if [ -z \$EESSI_VERSION ]; then" >> ${BASHRC}
    echo "    source /cvmfs/software.eessi.io/versions/${REQUESTED_EESSI_VERSION}/init/lmod/bash" >> ${BASHRC}
    echo "fi" >> ${BASHRC}
    echo 'export PATH="/opt/jupyter-env/bin:$HOME/.local/bin:$PATH"' >> ${BASHRC}
fi

chown -R ${USER}:${USER} /home/${USER}

# Mount EESSI CVMFS repository
mkdir -p /cvmfs/software.eessi.io
mount -t cvmfs software.eessi.io /cvmfs/software.eessi.io

source /cvmfs/software.eessi.io/versions/${REQUESTED_EESSI_VERSION}/init/lmod/bash

# Ensure AITW-notebooks directory exists and populate it if empty
NOTEBOOK_DIR="/home/${USER}/AITW-notebooks"
if [ ! -d "${NOTEBOOK_DIR}" ]; then
    git clone https://github.com/AI-TranspWood/jupyter-notebooks.git ${NOTEBOOK_DIR}
    chown -R ${USER}:${USER} ${NOTEBOOK_DIR}
fi


# Run JupyterLab from EESSI as specified user
cd ${NOTEBOOK_DIR}
su -c '
source /cvmfs/software.eessi.io/versions/${REQUESTED_EESSI_VERSION}/init/lmod/bash
export JUPYTER_PATH="/eessi_kernels/$EESSI_SOFTWARE_SUBDIR:$JUPYTER_PATH"

export PATH="/opt/jupyter-env/bin:$HOME/.local/bin:$PATH"

count=0
LIMIT=20
while [ $count -lt $LIMIT ]; do
    if [ -f ${HOME}/flask_port.env ] && [ -f ${HOME}/jupyter_port.env ]; then
        break
    fi
    echo "Waiting for port files to be created..."
    sleep 1
    count=$((count + 1))
    if [ $count -eq $LIMIT ]; then
        echo "Timeout waiting for port files to be created. Some services may not be available."
    fi
done
export FLASK_PORT_EXT=`cat ${HOME}/flask_port.env`
export JUPYTER_PORT_EXT=`cat ${HOME}/jupyter_port.env`

envsubst '\''$FLASK_PORT_EXT $JUPYTER_PORT_EXT'\'' < jp_app_launcher.yml.tpl > jp_app_launcher.yml

# It is important to go into JupyterLab without any EESSI version loaded.
# This allows to go into a notebook and run `module purge` without removing the compat layer paths from PATH and
# breaking the environment for successive module operations (many normal binaries no longer available).
module purge

export OMP_NUM_THREADS=1
export OMPI_MCA_osc=^ucx
export OMPI_MCA_btl=^openib,ofi
export OMPI_MCA_plm=isolated  # Run on a single node and avoid using ssh to launch processes
export OMPI_MCA_mtl=^ofi
export OMPI_MCA_btl_tcp_if_exclude=docker0,127.0.0.0/8

jupyter lab \
    --NotebookApp.open_browser="False" \
    --NotebookApp.disable_check_xsrf="True" \
    --MappingKernelManager.cull_idle_timeout=120 \
    --MappingKernelManager.cull_interval=15 \
    --ip 0.0.0.0
' ${USER}
