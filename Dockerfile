# Design2GarmentCode Docker image for RunPod
# GPU-enabled with CUDA 12.1 support
# Using runtime (not devel) to save space - build tools installed separately

FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies (including OSMesa and EGL for headless 3D rendering)
# Combined with build-essential for any compilation needs
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    libgl1-mesa-glx \
    libgl1-mesa-dev \
    libegl1-mesa \
    libegl1-mesa-dev \
    libosmesa6 \
    libosmesa6-dev \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libcairo2-dev \
    libffi-dev \
    libpango1.0-dev \
    libgdk-pixbuf2.0-dev \
    libpangocairo-1.0-0 \
    libgdk-pixbuf-2.0-0 \
    shared-mime-info \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Cloudflared for tunneling
RUN wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

# Accept conda TOS
RUN conda config --set auto_activate_base false && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true

# Set working directory
WORKDIR /app

# Copy environment and requirements files first for caching
COPY environment_runpod.yml /app/environment_runpod.yml
COPY requirements_runpod.txt /app/requirements_runpod.txt

# Create conda environment (base packages only - no pip section)
RUN conda env create -f environment_runpod.yml && \
    conda clean -afy && \
    rm -rf /opt/conda/pkgs/*

# Make RUN commands use the conda environment
SHELL ["conda", "run", "-n", "d2g", "/bin/bash", "-c"]

# Install PyTorch and ML dependencies - clean up immediately after
RUN pip install --no-cache-dir -r requirements_runpod.txt && \
    rm -rf ~/.cache/pip/* /tmp/*

# Copy the rest of the application
COPY . /app

# Install NvidiaWarp-GarmentCode for 3D simulation
ENV CUDA_PATH=/usr/local/cuda
RUN git clone --depth 1 https://github.com/maria-korosteleva/NvidiaWarp-GarmentCode.git /tmp/warp && \
    cd /tmp/warp && \
    chmod -R +x tools/ && \
    python build_lib.py && \
    pip install -e . && \
    rm -rf /tmp/warp/.git /tmp/warp/docs

# Create directories for models and logs
RUN mkdir -p /app/lmm_utils/Qwen/Qwen2-VL-2B-Instruct && \
    mkdir -p /app/lmm_utils/Qwen/qwen2vl_lora_mlp && \
    mkdir -p /app/Logs && \
    mkdir -p /app/outputs && \
    mkdir -p /app/tmp_gui

# Skip models during build - download at runtime to keep image small
# Models will be downloaded by entrypoint and persisted via volume mount

# Copy entrypoint script
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

# Expose port for GUI
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
ENV HF_HOME=/app/.cache/huggingface
ENV PYOPENGL_PLATFORM=osmesa

# Entrypoint handles model download check and config
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["python", "gui.py", "--host", "0.0.0.0", "--port", "8080"]
