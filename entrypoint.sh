#!/bin/bash

USER=eessi-user

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
EOF

BASHRC="/home/${USER}/.bashrc"
if [ -z "`grep 'module ' ${BASHRC}`" ]; then
    echo 'source /cvmfs/software.eessi.io/versions/2023.06/init/bash' >> ${BASHRC}
    echo 'module reload' >> ${BASHRC}
    echo 'export PATH="/opt/jupyter-env/bin:$HOME/.local/bin:$PATH"' >> ${BASHRC}
fi

chown -R ${USER}:${USER} /home/${USER}

# Mount EESSI CVMFS repository
mkdir -p /cvmfs/software.eessi.io
mount -t cvmfs software.eessi.io /cvmfs/software.eessi.io

source /cvmfs/software.eessi.io/versions/2023.06/init/bash

# Ensure AITW-notebooks directory exists and populate it if empty
NOTEBOOK_DIR="/home/${USER}/AITW-notebooks"
if [ ! -d "${NOTEBOOK_DIR}" ]; then
    git clone https://github.com/AI-TranspWood/jupyter-notebooks.git ${NOTEBOOK_DIR}
    chown -R ${USER}:${USER} ${NOTEBOOK_DIR}
fi


# Run JupyterLab from EESSI as specified user
cd ${NOTEBOOK_DIR}
su -c '
source /cvmfs/software.eessi.io/versions/2023.06/init/bash

export PATH="/opt/jupyter-env/bin:$HOME/.local/bin:$PATH"

export OMP_NUM_THREADS=1                                      
export OMPI_MCA_osc=^ucx                                      
export OMPI_MCA_btl=^openib,ofi                               
export OMPI_MCA_pml=^ucx                                      
export OMPI_MCA_mtl=^ofi                                      
export OMPI_MCA_btl_tcp_if_exclude=docker0,127.0.0.0/8 

jupyter lab \
    --NotebookApp.token="" \
    --NotebookApp.open_browser="False" \
    --NotebookApp.disable_check_xsrf="True" \
    --MappingKernelManager.cull_idle_timeout=120 \
    --MappingKernelManager.cull_interval=15 \
    --ip 0.0.0.0
' ${USER}
