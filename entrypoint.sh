#!/bin/bash

USER=eessi-user

# Needed to avoid `Failed to initialize loader socket` error
# Needs to be inside the entrypoint script in case of volume mounts
mkdir -p /cvmfs-cache
chown -R cvmfs:cvmfs /cvmfs-cache

# Ensure Jupyter config directory exists and is owned by the specified user
rm -fr /home/${USER}/.jupyter
mkdir -p /home/${USER}/.jupyter/lab/workspaces

BASHRC="/home/${USER}/.bashrc"
if [ -z "`grep 'module ' ${BASHRC}`" ]; then
    echo 'source /cvmfs/software.eessi.io/versions/2023.06/init/bash' >> ${BASHRC}
    echo 'module purge' >> ${BASHRC}
    echo 'module load EESSI-extend' >> ${BASHRC}
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ${BASHRC}
fi

chown -R ${USER}:${USER} /home/${USER}
# chown -R ${USER}:${USER} /home/${USER}/.jupyter/lab/workspaces

# Mount EESSI CVMFS repository
mkdir -p /cvmfs/software.eessi.io
mount -t cvmfs software.eessi.io /cvmfs/software.eessi.io


# Run JupyterLab from EESSI as specified user
cd /home/${USER}
su -c '
source /cvmfs/software.eessi.io/versions/2023.06/init/bash

export OMP_NUM_THREADS=1                                      
export OMPI_MCA_osc=^ucx                                      
export OMPI_MCA_btl=^openib,ofi                               
export OMPI_MCA_pml=^ucx                                      
export OMPI_MCA_mtl=^ofi                                      
export OMPI_MCA_btl_tcp_if_exclude=docker0,127.0.0.0/8 

module load JupyterLab
module load jupyterlmod/4.0.3-GCCcore-12.3.0

jupyter lab \
    --NotebookApp.token="" \
    --NotebookApp.open_browser="False" \
    --NotebookApp.disable_check_xsrf="True" \
    --ip 0.0.0.0
' ${USER}

tail -f /dev/null
