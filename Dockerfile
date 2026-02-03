# Design2GarmentCode Docker image for RunPod
# GPU-enabled with CUDA 12.1 support

FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies (including OSMesa and EGL for headless 3D rendering)
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
    && rm -rf /var/lib/apt/lists/*

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

# Copy environment file first for caching
COPY environment_runpod.yml /app/environment_runpod.yml

# Create conda environment
RUN conda env create -f environment_runpod.yml && \
    conda clean -afy

# Make RUN commands use the conda environment
SHELL ["conda", "run", "-n", "d2g", "/bin/bash", "-c"]

# Copy the rest of the application
COPY . /app

# Install NvidiaWarp-GarmentCode for 3D simulation
ENV CUDA_PATH=/usr/local/cuda
RUN git clone https://github.com/maria-korosteleva/NvidiaWarp-GarmentCode.git /tmp/warp && \
    cd /tmp/warp && \
    python build_lib.py && \
    pip install -e . && \
    rm -rf /tmp/warp/.git

# Create directories for models and logs
RUN mkdir -p /app/lmm_utils/Qwen/Qwen2-VL-2B-Instruct && \
    mkdir -p /app/lmm_utils/Qwen/qwen2vl_lora_mlp && \
    mkdir -p /app/Logs && \
    mkdir -p /app/outputs && \
    mkdir -p /app/tmp_gui

# Download models during build (optional - can be skipped with --build-arg SKIP_MODELS=1)
ARG SKIP_MODELS=0
RUN if [ "$SKIP_MODELS" = "0" ]; then \
    echo "Downloading Qwen2-VL-2B-Instruct model..." && \
    python -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='Qwen/Qwen2-VL-2B-Instruct', local_dir='lmm_utils/Qwen/Qwen2-VL-2B-Instruct')" && \
    echo "Downloading fine-tuned weights..." && \
    pip install -q gdown && \
    gdown --id 1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U- -O lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth && \
    echo "Models downloaded successfully!"; \
    else echo "Skipping model download (SKIP_MODELS=1)"; fi

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
