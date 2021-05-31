#!/bin/bash

set -vex

# Needs a bazel build:
# com_google_absl
# Build failures in tensorflow/core/platform/s3/aws_crypto.cc
# boringssl (i.e. system openssl)
# Most importantly: Write a patch that uses system LLVM libs for sure as well as MLIR and oneDNN/mkldnn
# TODO(check):
# absl_py
# com_github_googleapis_googleapis
# com_github_googlecloudplatform_google_cloud_cpp
# Needs c++17, try on linux
#  com_googlesource_code_re2

# The possible values are specified in third_party/systemlibs/syslibs_configure.bzl
# The versions for them can be found in tensorflow/workspace.bzl
export TF_SYSTEM_LIBS="
  absl_py
  astor_archive
  astunparse_archive
  boringssl
  com_github_googleapis_googleapis
  com_github_googlecloudplatform_google_cloud_cpp
  com_github_grpc_grpc
  com_google_protobuf
  curl
  cython
  dill_archive
  flatbuffers
  gast_archive
  gif
  icu
  libjpeg_turbo
  org_sqlite
  png
  pybind11
  snappy
  zlib
  "

# do not build with MKL support
export TF_NEED_MKL=0
export BAZEL_MKL_OPT=""

mkdir -p ./bazel_output_base
export BAZEL_OPTS=""
export CC_OPT_FLAGS="${CFLAGS}"

# Quick debug:
# cp -r ${RECIPE_DIR}/build.sh . && bazel clean && bash -x build.sh --logging=6 | tee log.txt
# Dependency graph:
# bazel query 'deps(//tensorflow/tools/lib_package:libtensorflow)' --output graph > graph.in
if [[ "${target_platform}" == osx-* ]]; then
    export LDFLAGS="${LDFLAGS} -lz -framework CoreFoundation -Xlinker -undefined -Xlinker dynamic_lookup"
else
    export LDFLAGS="${LDFLAGS} -lrt"
fi

if [[ "${target_platform}" == "osx-64" ]]; then
    # Tensorflow doesn't cope yet with an explicit architecture (darwin_x86_64) on osx-64 yet.
    TARGET_CPU=darwin
fi

# If you really want to see what is executed, add --subcommands
BUILD_OPTS="
    --crosstool_top=//custom_toolchain:toolchain
    --logging=6
    --verbose_failures
    --config=opt
    --define=PREFIX=${PREFIX}
    --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include
    --cpu=${TARGET_CPU}"

if [[ "${target_platform}" == "osx-arm64" ]]; then
    BUILD_OPTS="${BUILD_OPTS} --config=macos_arm64"
fi
export TF_ENABLE_XLA=0
export BUILD_TARGET="//tensorflow/tools/pip_package:build_pip_package //tensorflow/tools/lib_package:libtensorflow //tensorflow:libtensorflow_cc.so"

# Python settings
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1

# additional settings
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

## cuda settings
if [[ ${cuda_compiler_version} != "None" ]]; then

    sed -i -e "s:\${PREFIX}:${PREFIX}:" tensorflow/core/platform/default/build_config/BUILD

    export CUDA_TOOLKIT_PATH=/usr/local/cuda-${cuda_compiler_version}
    export TF_CUDA_PATHS="${PREFIX},/usr/local/cuda-${cuda_compiler_version},/usr"
    export USE_CUDA=1
    export cuda=Y
    if [[ ${cuda_compiler_version} == 9.0* ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2
    elif [[ ${cuda_compiler_version} == 9.2* ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0
    elif [[ ${cuda_compiler_version} == 10.* ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0,7.2,7.5
    elif [[ ${cuda_compiler_version} == 11.0* ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0,7.2,7.5,8.0
    elif [[ ${cuda_compiler_version} == 11.1 ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0,7.2,7.5,8.0,8.6
    elif [[ ${cuda_compiler_version} == 11.2 ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=5.2,5.3,6.0,6.1,6.2,7.0,7.2,7.5,8.0,8.6
    else
        echo "unsupported cuda version. edit build_pytorch.sh"
        exit 1
    fi
    
    export TF_NEED_CUDA=1
    export TF_CUDA_VERSION="${cuda_compiler_version}"
    export TF_CUDNN_VERSION="${cudnn}"
    export TF_CUDA_CLANG=0
    export TF_DOWNLOAD_CLANG=0
    export TF_NEED_TENSORRT=0
    export GCC_HOST_COMPILER_PATH="${CC}"
    export TF_NCCL_VERSION=""
    export CC_OPT_FLAGS="-march=nocona -mtune=haswell"
    export GCC_HOST_COMPILER_PATH="${CC}"
    
    BUILD_OPTS="
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

    ## Doesn't work with CUDA builds, don't know why
    export TF_SYSTEM_LIBS=""
else
    export PATH="$PWD:$PATH"
    export CC=$(basename $CC)
    export CXX=$(basename $CXX)
    export LIBDIR=$PREFIX/lib
    export INCLUDEDIR=$PREFIX/include
    source ${RECIPE_DIR}/gen-bazel-toolchain.sh
    # Get rid of unwanted defaults
    sed -i -e "/PROTOBUF_INCLUDE_PATH/c\ " .bazelrc
    sed -i -e "/PREFIX/c\ " .bazelrc
fi

sed -i -e "s/GRPCIO_VERSION/${grpc_cpp}/" tensorflow/tools/pip_package/setup.py
echo $(bazel --version) | cut -d" " -f2 > tensorflow/.bazelversion

bazel clean --expunge
bazel shutdown

./configure
echo "build --config=noaws" >> .bazelrc

# build using bazel
bazel ${BAZEL_OPTS} build ${BUILD_OPTS} ${BUILD_TARGET}

# build a whl file
mkdir -p $SRC_DIR/tensorflow_pkg
bash -x bazel-bin/tensorflow/tools/pip_package/build_pip_package $SRC_DIR/tensorflow_pkg

