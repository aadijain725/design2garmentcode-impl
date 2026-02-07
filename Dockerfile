# Design2GarmentCode Docker image for RunPod
# Multi-stage build: devel for compilation, runtime for final image

#############################
# Stage 1: Build NvidiaWarp
#############################
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install build dependencies only
RUN apt-get update && apt-get install -y \
    wget curl git build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

# Accept conda TOS and create build env
RUN conda config --set auto_activate_base false && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true && \
    conda create -n build python=3.9 numpy -y && conda clean -afy

SHELL ["conda", "run", "-n", "build", "/bin/bash", "-c"]

# Build NvidiaWarp
ENV CUDA_PATH=/usr/local/cuda
WORKDIR /build
RUN git clone --depth 1 https://github.com/maria-korosteleva/NvidiaWarp-GarmentCode.git warp && \
    cd warp && \
    chmod -R +x tools/ && \
    python build_lib.py && \
    pip install -e .

#############################
# Stage 2: Final runtime image  
#############################
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    wget curl git \
    libgl1-mesa-glx libegl1-mesa libosmesa6 \
    libglib2.0-0 libsm6 libxext6 libxrender-dev \
    libcairo2 libffi8 libpango-1.0-0 libgdk-pixbuf2.0-0 \
    libpangocairo-1.0-0 shared-mime-info ffmpeg \
    && rm -rf /var/lib/apt/lists/* && apt-get clean

# Install Cloudflared
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

RUN conda config --set auto_activate_base false && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true && \
    conda tos accept --override-channels --channel conda-forge 2>/dev/null || true

WORKDIR /app

# Copy environment files
COPY environment_runpod.yml /app/environment_runpod.yml
COPY requirements_runpod.txt /app/requirements_runpod.txt

# Create conda environment
RUN conda env create -f environment_runpod.yml && \
    conda clean -afy && rm -rf /opt/conda/pkgs/*

SHELL ["conda", "run", "-n", "d2g", "/bin/bash", "-c"]

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements_runpod.txt && rm -rf ~/.cache/pip/*

# Copy NvidiaWarp from builder (including compiled binaries in warp/bin/)
COPY --from=builder /build/warp /app/warp
ENV PYTHONPATH="/app/warp:${PYTHONPATH}"
# Verify warp loads correctly
RUN python -c "import warp as wp; wp.init(); print('Warp initialized successfully')"

# Copy application
COPY . /app

# Backup files that might be hidden by volume mounts
RUN mkdir -p /app/.repo_backup && \
    cp /app/lmm_utils/Qwen/qwen2vl_lora_mlp/qwen2vl_modify_modeling_qwen2_vl.py /app/.repo_backup/ 2>/dev/null || true

# Create directories
RUN mkdir -p /app/lmm_utils/Qwen/Qwen2-VL-2B-Instruct \
    /app/lmm_utils/Qwen/qwen2vl_lora_mlp \
    /app/Logs /app/outputs /app/tmp_gui

# Setup entrypoint
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 8080

ENV PYTHONUNBUFFERED=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
ENV HF_HOME=/app/.cache/huggingface
ENV PYOPENGL_PLATFORM=osmesa

ENTRYPOINT ["/app/docker-entrypoint.sh"]
# Default: keep container alive for SSH access. Run GUI manually when needed.
CMD ["sleep", "infinity"]
