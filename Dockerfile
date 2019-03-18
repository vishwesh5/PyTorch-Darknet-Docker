FROM 	nvidia/cuda:8.0-cudnn7-devel-ubuntu16.04 AS build-env

LABEL 	maintainer="Vishwesh Ravi Shrimali <vishweshshrimali5@gmail.com>"

ARG 	NB_USER="jovyan"
ARG 	NB_UID="1000"
ARG 	NB_GID="100"

USER 	root

ENV 	DEBIAN_FRONTEND noninteractive

ENV 	cvVersion="master"
ENV 	cwd="/opt"

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
RUN 	apt-get update && apt-get -yq dist-upgrade \
 	&& apt-get install -yq --no-install-recommends \
    	wget \
    	bzip2 \
    	ca-certificates \
    	sudo \
    	locales \
    	fonts-liberation \
 	&& rm -rf /var/lib/apt/lists/*

RUN 	echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    	locale-gen

# Configure environment
ENV 	CONDA_DIR=/opt/conda \
    	SHELL=/bin/bash \
    	NB_USER=$NB_USER \
    	NB_UID=$NB_UID \
	NB_GID=$NB_GID \
    	LC_ALL=en_US.UTF-8 \
    	LANG=en_US.UTF-8 \
    	LANGUAGE=en_US.UTF-8 \
 	PATH=$CONDA_DIR/bin:$PATH \
    	HOME=/home/$NB_USER

# Add a script that we will use to correct permissions after running certain commands
ADD 	fix-permissions /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN 	sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Create NB_USER wtih name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN 	groupadd wheel -g 11 && \
    	echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    	useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    	mkdir -p $CONDA_DIR && \
    	chown $NB_USER:$NB_GID $CONDA_DIR && \
    	chmod g+w /etc/passwd && \
    	fix-permissions $HOME && \
    	fix-permissions "$(dirname $CONDA_DIR)"

USER 	$NB_UID

# Setup work directory for backward-compatibility
RUN 	mkdir /home/$NB_USER/work && \
    	fix-permissions /home/$NB_USER

	# Install conda as jovyan and check the md5 sum provided on the download site
ENV 	MINICONDA_VERSION=4.5.12 \
    	CONDA_VERSION=4.6.7

RUN 	cd /tmp && \
    	wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    	echo "866ae9dff53ad0874e1d1a60b1ad1ef8 *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    	/bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    	rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    	$CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    	$CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    	$CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    	$CONDA_DIR/bin/conda install --quiet --yes conda="${CONDA_VERSION%.*}.*" && \
    	$CONDA_DIR/bin/conda update --all --quiet --yes && \
    	conda clean -tipsy && \
    	rm -rf /home/$NB_USER/.cache/yarn && \
    	fix-permissions $CONDA_DIR && \
    	fix-permissions /home/$NB_USER

# Install Tini
RUN 	conda install --quiet --yes 'tini=0.18.0' && \
    	conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    	conda clean -tipsy && \
    	fix-permissions $CONDA_DIR && \
    	fix-permissions /home/$NB_USER

# Install Jupyter Notebook, Lab, and Hub
# Generate a notebook server config
# Cleanup temporary files
# Correct permissions
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change
RUN 	conda install --quiet --yes \
    	'notebook=5.7.5' \
    	'jupyterhub=0.9.4' \
    	'jupyterlab=0.35.4' && \
    	conda clean -tipsy && \
    	jupyter labextension install @jupyterlab/hub-extension@^0.12.0 && \
    	npm cache clean --force && \
    	jupyter notebook --generate-config && \
    	rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
	rm -rf /home/$NB_USER/.cache/yarn && \
	fix-permissions $CONDA_DIR && \
    	fix-permissions /home/$NB_USER

USER 	root

EXPOSE 	8888
WORKDIR $HOME

USER 	root

WORKDIR $cwd

RUN     apt-get update --fix-missing && \
        apt-get install -y --no-install-recommends \
        software-properties-common && \
        add-apt-repository "deb http://security.ubuntu.com/ubuntu xenial-security main" && \
	apt -y update && \
	apt-get install -y --no-install-recommends \
	build-essential \
	libx11-dev \
	libboost-python-dev \
	checkinstall \
	cmake \
	pkg-config \
	yasm \
	unzip \
	git \
	gfortran \
	libjpeg8-dev \
	libpng-dev \
        libgstreamer1.0-dev \
	libgstreamer-plugins-base1.0-dev \
	libgtk2.0-dev \
	libtbb-dev \
	qt5-default \
	libatlas-base-dev \
	libfaac-dev \
	libmp3lame-dev \
	libtheora-dev \
	libvorbis-dev \
	libxvidcore-dev \
	libopencore-amrnb-dev \
	libopencore-amrwb-dev \
	libavresample-dev \
	x264 \
	v4l-utils \
	libprotobuf-dev \
	protobuf-compiler \
	libgoogle-glog-dev \
	libgflags-dev \
	libgphoto2-dev \
	libeigen3-dev \
	libhdf5-dev \
	doxygen \
        libjasper1 \
	libtiff-dev \
	libavcodec-dev \
	libavformat-dev \
	libswscale-dev \
	libdc1394-22-dev \
	libxine2-dev \
	libv4l-dev \
	wget \
	vim && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* && \
        cd /usr/include/linux && \
	ln -s -f ../libv4l1-videodev.h videodev.h && \
	cd $cwd && \
        git clone https://github.com/opencv/opencv.git && \
	cd opencv && \
	git checkout $cvVersion && \
	cd .. && \
        git clone https://github.com/opencv/opencv_contrib.git && \
	cd opencv_contrib && \
	git checkout $cvVersion && \
	cd .. 


USER    $NB_UID

RUN	conda install -y xeus-cling notebook -c QuantStack -c conda-forge && \
	conda create -y -f -n OpenCV-"$cvVersion"-py3 python=3.7 anaconda && \
	conda install -y -n OpenCV-"$cvVersion"-py3 numpy scipy matplotlib scikit-image scikit-learn ipython ipykernel pandas && \
        conda install -y -n OpenCV-"$cvVersion"-py3 pytorch -c pytorch && \
        conda install -y -n OpenCV-"$cvVersion"-py3 torchvision -c pytorch && \
        conda install -y -n OpenCV-"$cvVersion"-py3 -c pytorch -c fastai fastai && \
        conda clean --all -y && \
        /bin/bash -c "source $CONDA_DIR/bin/activate OpenCV-\"$cvVersion\"-py3 && \
        python -m pip install tensorflow && \
        python -m pip install keras"

USER    root

RUN	/bin/bash -c "source $CONDA_DIR/bin/activate OpenCV-\"$cvVersion\"-py3 && \
	python -m ipykernel install --name OpenCV-\"$cvVersion\"-py3"

USER    $NB_UID

RUN	fix-permissions $CONDA_DIR && \
	fix-permissions /home/$NB_USER

USER    root

WORKDIR $CONDA_DIR/envs/

RUN     mkdir OpenCV-"$cvVersion"-py3/opencv_include && \
	cp -r OpenCV-"$cvVersion"-py3/include/* OpenCV-"$cvVersion"-py3/opencv_include && \
	cp -r OpenCV-"$cvVersion"-py3/opencv_include/python3.7m/* OpenCV-"$cvVersion"-py3/opencv_include

WORKDIR $cwd

RUN     cd opencv && \
	mkdir build && \
	cd build && \
	cmake -DCMAKE_BUILD_TYPE=RELEASE \
	-DCMAKE_INSTALL_PREFIX=/usr/local \
	-DINSTALL_C_EXAMPLES=ON \
	-DWITH_TBB=ON \
	-DWITH_V4L=ON \
	-DWITH_QT=ON \
	-DWITH_OPENGL=ON \
	-DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules \
	-DPYTHON3_EXECUTABLE=$CONDA_DIR/envs/OpenCV-"$cvVersion"-py3/bin/python \
	-DPYTHON3_INCLUDE_DIR=$CONDA_DIR/envs/OpenCV-"$cvVersion"-py3/opencv_include \
	-DPYTHON3_LIBRARY=$CONDA_DIR/envs/OpenCV-"$cvVersion"-py3/lib/libpython3.7m.so \
	-DPYTHON3_NUMPY_INCLUDE_DIRS=$CONDA_DIR/envs/OpenCV-"$cvVersion"-py3/lib/python3.7/site-packages/numpy/core/include \
	-DPYTHON3_PACKAGES_PATH=$CONDA_DIR/envs/OpenCV-"$cvVersion"-py3/lib/python3.7/site-packages .. && \
	make -j4 && make install && \
	cd .. && \
        /bin/sh -c 'echo "/usr/local/lib" >> /etc/ld.so.conf.d/opencv.conf' && \
        ldconfig && \
        /bin/sh -c 'py3binPath=$(find /usr/local/lib/ -type f -name "cv2.cpython*.so") && \
	cd /opt/conda/envs/OpenCV-$cvVersion-py3/lib/python3.7/site-packages && \
	ln -f -s $py3binPath cv2.so'

WORKDIR $cwd

ENV     PATH $CONDA_DIR/bin:$PATH

RUN     chown $NB_USER:$NB_GID $CONDA_DIR && \
        rm /opt/conda/envs/OpenCV-"$cvVersion"-py3/lib/libfontconfig.so.1 && \
        rm -rf $cwd/opencv && \
        rm -rf $cwd/opencv_contrib

WORKDIR $HOME

RUN     ln -s /usr/local/cuda-8.0 /usr/local/cuda && \
        git clone https://github.com/pjreddie/darknet.git && \
        sed -i -e s/GPU=0/GPU=1/ darknet/Makefile && \
        sed -i -e s/CUDNN=0/CUDNN=1/ darknet/Makefile && \ 
        cd darknet && \
        make && \
        cd .. && \
        mv darknet darknet_pjreddie_gpu && \
        git clone https://github.com/AlexeyAB/darknet.git && \
        sed -i -e s/GPU=0/GPU=1/ darknet/Makefile && \
        sed -i -e s/CUDNN=0/CUDNN=1/ darknet/Makefile && \
        mv darknet darknet_alexeyab_gpu && \
        cd darknet_alexeyab_gpu && \
        make && \
        cd .. && \
        git clone https://github.com/pjreddie/darknet.git && \
        sed -i -e s/OPENMP=0/OPENMP=1/ darknet/Makefile && \
        cd darknet && \
        make && \
        cd .. && \
        mv darknet darknet_pjreddie_cpu && \
        git clone https://github.com/AlexeyAB/darknet.git && \
        sed -i -e s/OPENMP=0/OPENMP=1/ darknet/Makefile && \
        mv darknet darknet_alexeyab_cpu && \
        cd darknet_alexeyab_cpu && \
        make && \
        cd ..

RUN     chown $NB_USER:$NB_GID $HOME

USER 	$NB_UID

WORKDIR $HOME

ENV	DEBIAN_FRONTEND teletype
