FROM debian:bookworm-slim

# Install CVMFS and dependencies
RUN apt update && \
    apt install -y wget lsb-release && \
    wget https://cvmrepo.s3.cern.ch/cvmrepo/apt/cvmfs-release-latest_all.deb && \
    dpkg -i cvmfs-release-latest_all.deb && \
    rm -f cvmfs-release-latest_all.deb && \
    apt update && \
    apt install -y cvmfs

# Needed for mpirun to not give PLM related errors with the default configurations
RUN apt install -y openssh-client
# Use native python to create a jupyterlab environment
RUN apt install -y python3 python3-venv python3-pip
RUN rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/jupyter-env
# Fix version of jupyter_core to ensure the aforementioned patch works correctly
RUN /opt/jupyter-env/bin/pip install \
    jupyter_core==5.9.1 jupyterlab \
    ipywidgets \
    jupyter_app_launcher \
    jupyterlmod \
    jupyter-archive \
    voila

# Apply patch to jupyter-core to allow using EB_ENV_JUPYTER_ROOT to define Jupyter paths and config locations
RUN wget https://github.com/easybuilders/easybuild-easyconfigs/raw/refs/heads/develop/easybuild/easyconfigs/j/jupyter-server/jupyter-core-5.8.1_fix_jupyter_path.patch
RUN patch -d /opt/jupyter-env/lib/python3.11/site-packages/ -p1 < jupyter-core-5.8.1_fix_jupyter_path.patch
RUN rm jupyter-core-5.8.1_fix_jupyter_path.patch

RUN chown -R 1000:1000 /opt/jupyter-env

RUN mkdir -p /etc/cvmfs/keys/eessi.io
COPY eessi/software.eessi.io.conf /etc/cvmfs/config.d/
COPY eessi/eessi.io.pub /etc/cvmfs/keys/eessi.io/

RUN groupadd -g 1000 eessi-user
RUN useradd -u 1000 -g 1000 -m -s /bin/bash eessi-user

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
