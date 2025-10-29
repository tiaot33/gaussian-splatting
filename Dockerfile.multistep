# ---------- builder stage ----------
FROM nvidia/cuda:11.6.2-devel-ubuntu20.04 AS builder

# Install base utilities for building (NVCC, compilers present in devel image)
ENV DEBIAN_FRONTEND=noninteractive
# Run Qt applications (e.g., COLMAP) headlessly during build if needed
ENV QT_QPA_PLATFORM=offscreen
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        wget \
        ninja-build \
        unzip \
        libgl-dev \
        ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda (cleanup installer to reduce layer size)
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && /bin/bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm -f /tmp/miniconda.sh

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

WORKDIR /build/gaussian_splatting
COPY ./ ./

# Limit to architectures supported by PyTorch 1.12/CUDA 11.6 toolchain
# Avoid unknown arch errors during extension builds (e.g., 8.9, 9.0+PTX)
ENV TORCH_CUDA_ARCH_LIST="6.0;6.1;7.0;7.5;8.0;8.6"

ENV PIP_NO_CACHE_DIR=1

# Accept Anaconda TOS and create env with libmamba solver, then clean caches
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r \
    && conda update -n base -y conda \
    && conda install -n base -y conda-libmamba-solver \
    && conda config --set solver libmamba \
    && conda create -n gaussian_splatting -y python=3.7.13 pip=22.3.1 \
    && conda install -n gaussian_splatting -y -c pytorch -c conda-forge -c defaults \
        pytorch=1.12.1 torchvision=0.13.1 torchaudio=0.12.1 cudatoolkit=11.6 plyfile tqdm \
    && conda clean -afy

RUN conda init bash
SHELL ["conda", "run", "-n", "gaussian_splatting", "/bin/bash", "-c"]

# Build wheels for CUDA extensions and prepare environment content
RUN pip install --no-cache-dir -U pip setuptools wheel \
    && pip install --no-cache-dir opencv-python joblib \
    && conda config --set channel_priority strict \
    && ( \
         conda install -y -c conda-forge 'colmap=*=cuda*' \
      || conda install -y -c conda-forge 'colmap=*=gpu*' \
      || conda install -y -c conda-forge colmap \
       ) \
    && conda remove -y ffmpeg \
    && mkdir -p /opt/wheels \
    && cd submodules/diff-gaussian-rasterization && pip wheel . -w /opt/wheels && cd - \
    && cd submodules/simple-knn && pip wheel . -w /opt/wheels && cd - \
    && cd submodules/fused-ssim && pip wheel . -w /opt/wheels && cd - \
    && pip install --no-cache-dir /opt/wheels/*.whl \
    && rm -rf /opt/wheels \
    && pip cache purge || true \
    && conda clean -afy \
    && rm -rf /root/.cache


# ---------- runtime stage ----------
FROM nvidia/cuda:11.6.2-runtime-ubuntu20.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
# Ensure Qt runs headlessly inside the container (no X server required)
ENV QT_QPA_PLATFORM=offscreen
ENV XDG_RUNTIME_DIR=/tmp/runtime-root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgl1 \
        libegl1 \
        libopengl0 \
        libxkbcommon0 \
        libglib2.0-0 \
        ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create runtime dir for Qt to avoid warnings and allow headless contexts
RUN mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# Copy prebuilt conda env from builder
COPY --from=builder /opt/conda /opt/conda

# PATH for conda tools
ENV PATH=/opt/conda/bin:$PATH

WORKDIR /root/gaussian_splatting
COPY ./ ./

# Ensure conda shell available for subsequent commands
RUN conda init bash
SHELL ["conda", "run", "-n", "gaussian_splatting", "/bin/bash", "-c"]
# Make the image generic: no default service is started.
# Use `docker run -it <image> bash` for an interactive shell,
# or append commands (optionally via `conda run -n gaussian_splatting`).
CMD ["bash"]
