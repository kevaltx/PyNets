FROM debian:stretch-slim

# Pre-cache neurodebian key
COPY docker/files/neurodebian.gpg /root/.neurodebian.gpg

ARG DEBIAN_FRONTEND="noninteractive"

ENV LANG="C.UTF-8" \
    LC_ALL="C.UTF-8"

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends software-properties-common \
    # Install system dependencies.
    && apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        libxtst6 \
        libgtk2.0-bin \
        libxft2 \
        lib32ncurses5 \
        libxmu-dev \
        vim \
        wget \
        libgl1-mesa-glx \
        graphviz \
        libpng-dev \
        gnupg \
        build-essential \
        libgomp1 \
        libmpich-dev \
        mpich \
        ffmpeg \
        unzip \
        screen \
        git \
        g++ \
        zip \
        unzip \
        libglu1 \
        zlib1g-dev \
        libfreetype6-dev \
        pkg-config \
        r-base-core \
        libgsl0-dev \
        openssl \
        gsl-bin \
        libglu1-mesa-dev \
        libglib2.0-0 \
        libglw1-mesa \
	liblapack-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -o /tmp/libxp6.deb -sSL http://mirrors.kernel.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_amd64.deb \
    && dpkg -i /tmp/libxp6.deb && rm -f /tmp/libxp6.deb \
    # Add new user.
    && useradd --no-user-group --create-home --shell /bin/bash neuro \
    && chmod a+s /opt \
    && chmod 777 -R /opt

# Add Neurodebian package repositories (i.e. for FSL)
RUN curl -sSL http://neuro.debian.net/lists/stretch.us-tn.full >> /etc/apt/sources.list.d/neurodebian.sources.list && \
    apt-key add /root/.neurodebian.gpg && \
    (apt-key adv --refresh-keys --keyserver hkp://ha.pool.sks-keyservers.net 0xA5D32F012649A5A9 || true) && \
    apt-get update -qq
RUN apt-get update -qq && apt-get install -y --no-install-recommends fsl-core fsl-atlases fsl-mni-structural-atlas fsl-mni152-templates fsl-first-data

# Add git-lfs
# Configure git-lfs
RUN apt-get install -y apt-transport-https debian-archive-keyring
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get update && \
    apt-get install -y git-lfs

USER neuro
WORKDIR /home/neuro

# Install Miniconda.
ARG miniconda_version="4.3.27"
ENV PATH="/opt/conda/bin:$PATH"
RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-${miniconda_version}-Linux-x86_64.sh \
    && bash Miniconda3-${miniconda_version}-Linux-x86_64.sh -b -p /opt/conda \
    && conda config --system --prepend channels conda-forge \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && conda clean -tipsy \
    && rm -rf Miniconda3-${miniconda_version}-Linux-x86_64.sh

# Install pynets.
RUN conda install -yq python=3.6 ipython
RUN pip install --upgrade pip
RUN conda clean -tipsy
RUN pip install awscli pybids boto3 python-dateutil requests dipy scikit-image

#RUN git clone -b master https://github.com/dPys/PyNets PyNets && \
#    cd PyNets && \
#    pip install -r requirements.txt && \
#    python setup.py install
RUN pip install pynets==0.9.56

RUN git clone -b master https://github.com/dPys/nilearn.git nilearn && \
    cd nilearn && \
    python setup.py install

RUN sed -i '/mpl_patches = _get/,+3 d' /opt/conda/lib/python3.6/site-packages/nilearn/plotting/glass_brain.py \
    && sed -i '/for mpl_patch in mpl_patches:/,+2 d' /opt/conda/lib/python3.6/site-packages/nilearn/plotting/glass_brain.py

# Install skggm
RUN conda install -yq \
        cython \
        libgfortran \
        matplotlib \
        openblas \
    && conda clean -tipsy \
    && pip install skggm

USER root
RUN chown -R neuro /opt \
    && chmod a+s -R /opt \
    && chmod 775 -R /opt/conda/lib/python3.6/site-packages \
    && find /opt -type f -iname "*.py" -exec chmod 777 {} \;

# Cleanup
RUN apt-get remove --purge -y \
    git \
    build-essential

# Create mountpoints
RUN mkdir /inputs && \
    chmod -R 777 /inputs

RUN mkdir /outputs && \
    chmod -R 777 /outputs

USER neuro

# Python ENV Config
ENV LD_LIBRARY_PATH="/opt/conda/lib":$LD_LIBRARY_PATH

# Link to local packages
RUN echo PATH=\"\$HOME/.local/bin:\$PATH\" >> $HOME/.profile \
    && echo "shell -bash" >> ~/.screenrc

# PyNets ENV Config
ENV PATH="/opt/conda/lib/python3.6/site-packages/pynets:$PATH"

# FSL ENV Config
ENV FSLDIR=/usr/share/fsl/5.0
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV PATH=/usr/lib/fsl/5.0:$PATH
ENV FSLMULTIFILEQUIT=TRUE
ENV POSSUMDIR=/usr/share/fsl/5.0
ENV LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH
ENV FSLTCLSH=/usr/bin/tclsh
ENV FSLWISH=/usr/bin/wish
ENV FSLOUTPUTTYPE=NIFTI_GZ

# Misc environment vars
ENV PYTHONWARNINGS ignore

# Precaching fonts, set 'Agg' as default backend for matplotlib
RUN python -c "from matplotlib import font_manager" && \
    sed -i 's/\(backend *: \).*$/\1Agg/g' $( python -c "import matplotlib; print(matplotlib.matplotlib_fname())" )

# and add it as an entrypoint
ENTRYPOINT ["pynets_run.py"]
