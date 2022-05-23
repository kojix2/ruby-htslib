FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y wget zip \
    llvm-11 clang-11 libclang-11-dev libclang-cpp11-dev python3-pip

# Easiest way to get sufficiently new cmake appears to be using pip - Ubuntu 20.10 version is too old
RUN pip3 install --upgrade cmake

# Downlaod c2ffi 11.0.0
RUN wget https://github.com/rpav/c2ffi/archive/refs/heads/llvm-11.0.0.zip && \
    unzip llvm-11.0.0.zip && \
    mv c2ffi-llvm-11.0.0 /c2ffi && \
    rm llvm-11.0.0.zip

# Build c2ffi
RUN cd /c2ffi && \
        rm -rf build && mkdir -p build && cd build && \
        cmake -DBUILD_CONFIG=Release .. && make

WORKDIR /data
ENTRYPOINT ["/c2ffi/build/bin/c2ffi"]
