# Design2GarmentCode Docker image for RunPod
# GPU-enabled with CUDA 12.1 support

FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    libgl1-mesa-glx \
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

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

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

# Create directories for models
RUN mkdir -p /app/lmm_utils/Qwen/Qwen2-VL-2B-Instruct && \
    mkdir -p /app/lmm_utils/Qwen/qwen2vl_lora_mlp && \
    mkdir -p /app/Logs

# Expose port for GUI
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Default command - start the GUI
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "d2g"]
CMD ["python", "gui.py", "--host", "0.0.0.0", "--port", "8080"]
