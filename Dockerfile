FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu18.04
CMD nvidia-smi

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
        git \
        make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev  \
    	ffmpeg libsm6 libxext6 cmake libgl1-mesa-glx \
		&& rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash user
USER user

ENV HOME=/home/user \
	PATH=/home/user/.local/bin:$PATH

RUN curl https://pyenv.run | bash
ENV PATH=$HOME/.pyenv/shims:$HOME/.pyenv/bin:$PATH
RUN pyenv install 3.8.15 && \
    pyenv global 3.8.15 && \
    pyenv rehash && \
    pip install --no-cache-dir --upgrade pip setuptools wheel

ENV WORKDIR=/code
WORKDIR $WORKDIR
RUN chown -R user:user $WORKDIR
RUN chmod -R 777 $WORKDIR

COPY requirements.txt $WORKDIR/requirements.txt
RUN pip install --no-cache-dir --upgrade -r $WORKDIR/requirements.txt
RUN pip install ninja

COPY . .

ARG TORCH_CUDA_ARCH_LIST=7.5+PTX

USER root
RUN chown -R user:user $HOME
RUN chmod -R 777 $HOME
RUN chown -R user:user $WORKDIR
RUN chmod -R 777 $WORKDIR

USER user
RUN ln -s $WORKDIR/annotator/OneFormer/oneformer/modeling/pixel_decoder/ops $WORKDIR/ && ls 
RUN cd ops/ && FORCE_CUDA=1 python setup.py build --build-base=$WORKDIR/ install --user && cd ..
RUN sh deform_setup.sh

USER user
RUN sh deform_setup.sh

USER user

ENV PYTHONPATH=${HOME}/app \
    PYTHONUNBUFFERED=1 \
    GRADIO_ALLOW_FLAGGING=never \
    GRADIO_NUM_PORTS=1 \
    GRADIO_SERVER_NAME=0.0.0.0 \
    GRADIO_THEME=huggingface \
    SYSTEM=spaces

RUN --mount=type=secret,id=ACCESS_TOKEN,mode=0444,required=true


EXPOSE 7860

ENTRYPOINT ["python", "app.py"]