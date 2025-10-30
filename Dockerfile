FROM nvidia/cuda:11.6.2-devel-ubuntu20.04

# Install base utilities
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y build-essential wget git ninja-build unzip libgl-dev ffmpeg\
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install miniconda
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && /bin/bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm -f /tmp/miniconda.sh

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

WORKDIR /root/gaussian_splatting
COPY ./ ./

# Ensure submodules are present for pip local installs in environment.yml
# Mark repo as safe to avoid "dubious ownership" errors when running as root
RUN git config --global --add safe.directory /root/gaussian_splatting \
    && git submodule update --init --recursive

ENV TORCH_CUDA_ARCH_LIST="3.5;5.0;6.0;6.1;7.0;7.5;8.0;8.6+PTX"
ENV PIP_NO_CACHE_DIR=1
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r \
    && conda update -n base -y conda \
    && conda install -n base -y conda-libmamba-solver \
    && conda config --set solver libmamba 
RUN conda env create -f environment.yml \
    && conda clean -afy
RUN conda init bash
#RUN echo "conda activate gaussian_splatting" >> ~/.bashrc
SHELL ["conda", "run", "-n", "gaussian_splatting", "/bin/bash", "-c"]
RUN conda install -y https://anaconda.org/conda-forge/colmap/3.8/download/linux-64/colmap-3.8-gpuh0e4589b_101.conda \
    && conda remove ffmpeg -y


ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "gaussian_splatting"]
CMD ["bash"]
