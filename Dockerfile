FROM debian:bookworm-slim

RUN apt update && \
    apt install -y wget lsb-release && \
    wget https://cvmrepo.s3.cern.ch/cvmrepo/apt/cvmfs-release-latest_all.deb && \
    dpkg -i cvmfs-release-latest_all.deb && \
    rm -f cvmfs-release-latest_all.deb && \
    apt update && \
    apt install -y cvmfs

RUN apt install -y openssh-client
RUN rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/cvmfs/keys/eessi.io
COPY eessi/software.eessi.io.conf /etc/cvmfs/config.d/
COPY eessi/eessi.io.pub /etc/cvmfs/keys/eessi.io/

RUN groupadd -g 1000 eessi-user
RUN useradd -u 1000 -g 1000 -m -s /bin/bash eessi-user

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
