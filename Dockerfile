ARG TORCH_VERSION=2.5.1
ARG TORCH_VISION_VERSION=0.20.1
ARG CUDA_VERSION=12.4
ARG MAX_GCC_VERSION=13.2
ARG TORCH_CUDA_ARCH_LIST="8.9"
ARG BUILD_WITH_MODELS="true"

FROM pytorch/pytorch:${TORCH_VERSION}-cuda${CUDA_VERSION}-cudnn9-devel AS base_image

# Re-declare build arguments to use them in ENV
ARG TORCH_VERSION
ARG TORCH_VISION_VERSION
ARG CUDA_VERSION
ARG MAX_GCC_VERSION
ARG TORCH_CUDA_ARCH_LIST
ARG BUILD_WITH_MODELS

ENV TORCH_VERSION=${TORCH_VERSION}
ENV TORCH_VISION_VERSION=${TORCH_VISION_VERSION}
ENV CUDA_VERSION=${CUDA_VERSION}
ENV MAX_GCC_VERSION=${MAX_GCC_VERSION}
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}
ENV BUILD_WITH_MODELS=${BUILD_WITH_MODELS}

# Install build dependencies
RUN apt-get update

RUN <<-EOF
    set -e
    apt-get install -y ffmpeg build-essential git bash
    # bash -c "apt-get install gcc-$MAX_GCC_VERSION g++-$MAX_GCC_VERSION"
    # ln -s /usr/bin/gcc-$MAX_GCC_VERSION /usr/local/cuda/bin/gcc
    # ln -s /usr/bin/g++-$MAX_GCC_VERSION /usr/local/cuda/bin/g++
EOF

SHELL ["/bin/bash", "-c"]

COPY . /app/
WORKDIR /app

RUN git submodule init && \
    git submodule update --init --recursive && \
    git submodule update --recursive

RUN <<-EOF
    set -e

    pip install xformers==0.0.29.post1 flash-attn==2.7.2.post1 gradio==4.44.1 gradio_litmodel3d==0.0.1 spconv-cu${CUDA_VERSION//./} \
    imageio==2.36.1 imageio-ffmpeg==0.5.1 easydict==1.13 rembg==2.0.61 onnxruntime==1.20.1 plyfile==1.1 diffrp-nvdiffrast==0.3.3.1 trimesh==4.5.3 \
    xatlas==0.0.9  pyvista==0.44.2 pymeshfix==0.17.0 igraph==0.11.8 safetensors==0.5.0
    # pip install pillow imageio imageio-ffmpeg tqdm easydict opencv-python-headless scipy ninja rembg onnxruntime trimesh xatlas pyvista pymeshfix igraph transformers
    
    mkdir -p /tmp/libraries
    git clone https://github.com/EasternJournalist/utils3d.git /tmp/libraries/utils3d
    pip install /tmp/libraries/utils3d
    rm -rf /tmp/libraries
EOF

# Install dependencies
RUN pip install kaolin==0.17.0 -f https://nvidia-kaolin.s3.us-east-2.amazonaws.com/torch-${TORCH_VERSION}_cu${CUDA_VERSION//./}.html && python -c "import kaolin; print(kaolin.__version__)"

RUN <<-EOF
    set -e
    mkdir -p /tmp/extensions
    git clone https://github.com/autonomousvision/mip-splatting.git /tmp/extensions/mip-splatting
    pip install /tmp/extensions/mip-splatting/submodules/diff-gaussian-rasterization/
    
    cp -r extensions/vox2seq /tmp/extensions/vox2seq
    pip install /tmp/extensions/vox2seq
    rm -rf /tmp/extensions
EOF

ENV GRADIO_SERVER_NAME=0.0.0.0
ENV GRADIO_SERVER_PORT=8000
ENV GRADIO_ANALYTICS_ENABLED=False

EXPOSE 8000
EXPOSE 7860
    
CMD ["/bin/bash"]
