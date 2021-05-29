#!/bin/bash

set -ex

# Python settings
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1

# additional settings
export PATH="$PWD:$PATH"
export CC=$(basename $CC)
export CXX=$(basename $CXX)
export LIBDIR=$PREFIX/lib
export INCLUDEDIR=$PREFIX/include
export LDFLAGS="${LDFLAGS} -lrt"
export BUILD_TARGET="//tensorflow/tools/pip_package:build_pip_package //tensorflow/tools/lib_package:libtensorflow //tensorflow:libtensorflow_cc.so"
export BAZEL_MKL_OPT=""
export BAZEL_OPTS=""
export CC_OPT_FLAGS="${CFLAGS}"
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_CUDA=0
export TF_CUDA_CLANG=0
export TF_NEED_TENSORRT=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_CONFIGURE_IOS=0
export TF_IGNORE_MAX_BAZEL_VERSION=1
export TF_NEED_AWS=0
export TF_ENABLE_XLA=0
export TF_NEED_MKL=0
export GCC_HOST_COMPILER_PATH="${GCC}"
export GCC_HOST_COMPILER_PREFIX="$(dirname ${GCC})"
export TF_CUDA_PATHS="${PREFIX},/usr/local/cuda-${cuda_compiler_version},/usr"
export CLANG_CUDA_COMPILER_PATH=${PREFIX}/bin/clang
export USE_CUDA=1
export cuda=Y
export TF_NEED_CUDA=1
export TF_CUDA_VERSION="${cuda_compiler_version}"
export TF_CUDNN_VERSION="${cudnn}"
export TF_NCCL_VERSION=$(pkg-config nccl --modversion | grep -Po '\d+\.\d+')
export NCCL_ROOT_DIR=$PREFIX
export USE_STATIC_NCCL=0
export USE_STATIC_CUDNN=0
export PATH="${CUDA_HOME}/bin:$PATH"
export CUDA_TOOLKIT_ROOT_DIR=$CUDA_HOME
export LDFLAGS="${LDFLAGS//-Wl,-z,now/-Wl,-z,lazy}"
export CC_OPT_FLAGS="-march=nocona -mtune=haswell"

if [[ ${cuda_compiler_version} == 10.* ]]; then
    export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0,7.2,7.5
elif [[ ${cuda_compiler_version} == 11.0* ]]; then
    export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0,7.2,7.5,8.0
elif [[ ${cuda_compiler_version} == 11.1 ]]; then
    export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0,7.2,7.5,8.0,8.6
elif [[ ${cuda_compiler_version} == 11.2 ]]; then
    export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0,7.2,7.5,8.0,8.6
else
    echo "unsupported cuda version."
    exit 1
fi

## cuda builds don't work with custom_toolchain, instead we hard-code arguments, mostly copied
## from https://github.com/AnacondaRecipes/tensorflow_recipes/tree/master/tensorflow-base-gpu
BUILD_OPTS="
    --config=noaws
    --copt=-march=nocona
    --copt=-mtune=haswell
    --copt=-ftree-vectorize
    --copt=-fPIC
    --copt=-fstack-protector-strong
    --copt=-O2
    --cxxopt=-fvisibility-inlines-hidden
    --cxxopt=-fmessage-length=0
    --linkopt=-zrelro
    --linkopt=-znow
    --copt=-isystem${PREFIX}/include
    --copt=-L${PREFIX}/lib
    --linkopt=-L${PREFIX}/lib
    --verbose_failures
    --config=opt
    --config=cuda
    --strip=always
    --color=yes
    --curses=no
    --action_env=PYTHON_BIN_PATH=${PYTHON}
    --action_env=PYTHON_LIB_PATH=${SP_DIR}
    --python_path=${PYTHON}
    --define=PREFIX=$PREFIX
    --copt=-DNO_CONSTEXPR_FOR_YOU=1
    --host_copt=-DNO_CONSTEXPR_FOR_YOU=1
    --define=LIBDIR=$PREFIX/lib
    --define=INCLUDEDIR=$PREFIX/include"

mkdir -p ./bazel_output_base
# Allow any bazel version
echo "*" > tensorflow/.bazelversion

# Get rid of hardcoded versions, from
# https://github.com/archlinux/svntogit-community/blob/packages/tensorflow/trunk/PKGBUILD
sed -i -E "s/'([0-9a-z_-]+) .= [0-9].+[0-9]'/'\1'/" tensorflow/tools/pip_package/setup.py

bazel clean --expunge
bazel shutdown

./configure

# build using bazel
bazel ${BAZEL_OPTS} build ${BUILD_OPTS} ${BUILD_TARGET}

# build a whl file
mkdir -p $SRC_DIR/tensorflow_pkg
bash -x bazel-bin/tensorflow/tools/pip_package/build_pip_package $SRC_DIR/tensorflow_pkg
