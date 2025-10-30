# syntax=docker/dockerfile:1-labs
FROM nvidia/cuda:11.6.2-devel-ubuntu20.04

# Install base utilities
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y build-essential git curl ca-certificates ninja-build unzip libgl-dev ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install micromamba (per requirement: sh -c (curl -L micro.mamba.pm/install.sh))
# micromamba binary will be placed in /usr/local/bin
RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba

# Configure micromamba root and quiet output
ENV MAMBA_ROOT_PREFIX=/opt/conda
ENV MAMBA_NO_BANNER=1

WORKDIR /root/gaussian_splatting
COPY ./ ./

# Ensure submodules are present for pip local installs in environment.yml
# Mark repo as safe to avoid "dubious ownership" errors when running as root
RUN git config --global --add safe.directory /root/gaussian_splatting \
    && git submodule update --init --recursive

ENV TORCH_CUDA_ARCH_LIST="3.5;5.0;6.0;6.1;7.0;7.5;8.0;8.6+PTX"
ENV PIP_NO_CACHE_DIR=1

# Create the conda environment using micromamba
RUN --device=nvidia.com/gpu=all \
    --mount=type=cache,target=/opt/conda/pkgs \
    --mount=type=cache,target=/root/.cache/pip \
    micromamba create -y -n gaussian_splatting -f environment.yml \
    && ( \
    micromamba install -y -n gaussian_splatting -c conda-forge "cuda-version=11.6" "colmap=3.8=gpu*" \
    || micromamba install -y -c conda-forge colmap \
    ) \
    && ( micromamba remove -y ffmpeg || true ) \
    && micromamba clean -a -y

# Add entrypoint that activates the environment on container start
COPY entrypoint.sh /usr/local/bin/gs-entrypoint.sh
RUN chmod +x /usr/local/bin/gs-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/gs-entrypoint.sh"]
CMD ["bash"]
