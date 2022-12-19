# syntax=docker/dockerfile:1

FROM ubuntu:22.04

ARG GITHUB_TOKEN
ENV UK_KRAFT_GITHUB_TOKEN=${GITHUB_TOKEN}

# Install necessary packages available from standard repos
RUN apt-get update -qq && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y --no-install-recommends \
        # Software tools
        software-properties-common \
        build-essential \
        wget \
        curl \
        apt-utils \
        file \
        flex \
        bison \
        zip \
        unzip \
        uuid-runtime \
        openssh-client \
        gpg-agent \
        gnupg \
        ca-certificates \
        socat \
        rsync \
        git \
        python3 \
        python3-pip \
        neovim \
        nano \
        iproute2 \
        iputils-ping \
        net-tools \
        # Libraries
        libncurses-dev \
        libyaml-dev

RUN useradd --create-home appuser
USER appuser
WORKDIR /home/appuser

# Note(Florian): I needed to define this on Windows but it might not be necessary on your machine.
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Install Kraft
RUN pip3 install --upgrade \
        pip \
        requests \
        setuptools
RUN pip3 install git+https://github.com/unikraft/kraft.git

ENV PATH="${PATH}:/home/appuser/.local/bin"

RUN kraft list update

RUN git clone https://github.com/unikraft-upb/scripts && cd scripts/nolibc/ && ./do-httpreply setup
WORKDIR /home/appuser/scripts/nolibc
ENTRYPOINT ["/bin/bash", "/home/appuser/scripts/nolibc/do-httpreply", "build"]
