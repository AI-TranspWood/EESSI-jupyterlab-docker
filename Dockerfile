FROM python:3.13.7-slim-bookworm AS intermediate

RUN apt update && \
    apt install -y wget git patch && \
    rm -rf /var/lib/apt/lists/*

RUN pip install virtualenv
RUN mkdir -p /opt/jupyter-env
RUN chown -R 1000:1000 /opt/jupyter-env
RUN mkdir -p /pip_cache
RUN chown -R 1000:1000 /pip_cache

USER 1000:1000

RUN virtualenv /opt/jupyter-env

RUN mkdir -p /pip_cache
RUN --mount=type=cache,target=/pip_cache /opt/jupyter-env/bin/pip install --cache-dir \
    jupyter_core==5.9.1 jupyterlab \
    ipywidgets \
    jupyter_app_launcher \
    jupyterlmod \
    jupyter-archive \
    voila \
    git+https://github.com/Crivella/easybuild_jupyter_kernels

WORKDIR /tmp
RUN wget https://github.com/easybuilders/easybuild-easyconfigs/raw/refs/heads/develop/easybuild/easyconfigs/j/jupyter-server/jupyter-core-5.8.1_fix_jupyter_path.patch
RUN patch -d /opt/jupyter-env/lib/python3.13/site-packages/ -p1 < jupyter-core-5.8.1_fix_jupyter_path.patch
RUN rm jupyter-core-5.8.1_fix_jupyter_path.patch

FROM python:3.13.7-slim-bookworm

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
# RUN apt install -y python3 python3-venv python3-pip git
RUN rm -rf /var/lib/apt/lists/*

COPY --from=intermediate /opt/jupyter-env /opt/jupyter-env

RUN mkdir -p /etc/cvmfs/keys/eessi.io
COPY eessi/software.eessi.io.conf /etc/cvmfs/config.d/
COPY eessi/eessi.io.pub /etc/cvmfs/keys/eessi.io/

RUN groupadd -g 1000 eessi-user
RUN useradd -u 1000 -g 1000 -m -s /bin/bash eessi-user

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
