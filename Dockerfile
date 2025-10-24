FROM nvidia/cuda:11.6.2-devel-ubuntu20.04

# Install base utilities
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y build-essential wget ninja-build unzip libgl-dev ffmpeg\
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install miniconda
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

WORKDIR /root/gaussian_splatting
COPY ./ ./

# Limit to architectures supported by PyTorch 1.12/CUDA 11.6 toolchain
# Avoid unknown arch errors during extension builds (e.g., 8.9, 9.0+PTX)
ENV TORCH_CUDA_ARCH_LIST="6.0;6.1;7.0;7.5;8.0;8.6"

# Accept Anaconda TOS for default channels to enable non-interactive builds
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

RUN conda update -n base -y conda
RUN conda install -n base -y conda-libmamba-solver
RUN conda config --set solver libmamba
RUN conda create -n gaussian_splatting -y python=3.7.13 pip=22.3.1 \
    && conda install -n gaussian_splatting -y -c pytorch -c conda-forge -c defaults \
        pytorch=1.12.1 torchvision=0.13.1 torchaudio=0.12.1 cudatoolkit=11.6 plyfile tqdm
RUN conda init bash
#RUN echo "conda activate gaussian_splatting" >> ~/.bashrc
SHELL ["conda", "run", "-n", "gaussian_splatting", "/bin/bash", "-c"]
RUN pip install -U pip setuptools wheel
WORKDIR /root/gaussian_splatting/submodules/diff-gaussian-rasterization
RUN pip install .
WORKDIR /root/gaussian_splatting/submodules/simple-knn
RUN pip install .
WORKDIR /root/gaussian_splatting/submodules/fused-ssim
RUN pip install .
WORKDIR /root/gaussian_splatting
RUN pip install opencv-python joblib
RUN conda install -y jupyter colmap
RUN conda remove ffmpeg -y

WORKDIR /root/

ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "gaussian_splatting", "jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--allow-root"]
