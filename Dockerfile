# Define a build argument for the Alpine version to be used
ARG ALPINE_VERSION=3.20.3

# Use the specified Alpíne version as the base image for a common stage
FROM alpine:$ALPINE_VERSION AS common

# Update package lists and install common dependencies
RUN apk add --no-cache libgomp libstdc++ libgcc curl openblas

# Create the build stage, starting from the common stage
FROM common AS build

# Define build arguments, used to control various GGML optimizations
ARG CMAKE_ARGS=

# Define a build date argument to be used later in the image metadata
ARG BUILD_DATE=not-set

# Update package lists and install build dependencies
RUN apk add --no-cache build-base cmake git curl-dev openssl-dev openssl-libs-static openblas-dev linux-headers

# Clone the llama.cpp repository from GitHub with a shallow clone (only the latest commit)
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# Trick the compiler, to enable SSE3 without using a native build
ENV CFLAGS="-march=core2 -mtune=core2" \
    CXXFLAGS="-march=core2 -mtune=core2"

# Prepare the custom build
RUN cmake llama.cpp -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CCACHE=OFF \   
    -DGGML_NATIVE=OFF \
    -DLLAMA_CURL=ON \
    -DGGML_STATIC=ON \
    -DLLAMA_SERVER_SSL=ON \
    -DOPENSSL_USE_STATIC_LIBS=ON \
    -DGGML_RPC=ON \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=OpenBLAS \
    -DGGML_OPENMP=ON \
    -DLLAMA_BUILD_SERVER=ON \
    -DBUILD_SHARED_LIBS=OFF \
    ${CMAKE_ARGS}

# Clean
RUN cmake --build build --target clean

# Build
RUN cmake --build build --config Release --target llama-server -j $(nproc)

# Remove debugging symbols
RUN strip /build/bin/llama-server

# Create the runtime stage, starting from the common stage
FROM common AS runtime

# Add metadata labels to the final image, including the image title, description, source, license, and creation date
LABEL org.opencontainers.image.title="llama-server-cpu" \
      org.opencontainers.image.description="A (cpu-only) docker image based on ggerganov/llama.cpp" \
      org.opencontainers.image.source="https://github.com/raoni-gabriel/llama-server-cpu" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created=${BUILD_DATE}

# Set environment variables for runtime configurations of llama-server
ENV LC_ALL=C.utf8 \
    LLAMA_ARG_HOST=0.0.0.0 \
    LLAMA_ARG_ENDPOINT_METRICS=1 \
    LLAMA_ARG_PORT=11434

# Create a new user and group with ID 1000, and set the home directory for the user
RUN addgroup -g 1000 user && \
    adduser -u 1000 -G user -h /home/user -D user

# Define a health check command to monitor the container's health by checking the health endpoint
HEALTHCHECK CMD [ "curl", "-f", "http://localhost:11434/health" ]

# Expose port 11434 for llama-server to listen on (same as ollama)
EXPOSE 11434

# Define the entry point for the container, specifying the llama-server binary
ENTRYPOINT [ "/usr/local/bin/llama-server" ]

# Copy the built llama-server binary from the build stage to the runtime stage
COPY --from=build --chown=root:root /build/bin/llama-server /usr/local/bin/llama-server

# Run the container as the non-root user created earlier
USER user
WORKDIR /home/user
