FROM debian:bookworm-slim

RUN apt update && \
    apt install -y wget lsb-release && \
    wget https://cvmrepo.s3.cern.ch/cvmrepo/apt/cvmfs-release-latest_all.deb && \
    dpkg -i cvmfs-release-latest_all.deb && \
    rm -f cvmfs-release-latest_all.deb && \
    apt update && \
    apt install -y cvmfs

# Needed for mpirun to not give PLM related errors with the default configurations
RUN apt install -y openssh-client
# RUN apt install -y python3 python3-venv python3-pip
RUN rm -rf /var/lib/apt/lists/*

# RUN python3 -m venv /opt/jupyter-env
# RUN /opt/jupyter-env/bin/pip install \
#     jupyterlab \
#     jupyter_app_launcher \
#     jupyterlmod

# RUN chown -R 1000:1000 /opt/jupyter-env

RUN mkdir -p /etc/cvmfs/keys/eessi.io
COPY eessi/software.eessi.io.conf /etc/cvmfs/config.d/
COPY eessi/eessi.io.pub /etc/cvmfs/keys/eessi.io/

RUN groupadd -g 1000 eessi-user
RUN useradd -u 1000 -g 1000 -m -s /bin/bash eessi-user

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
