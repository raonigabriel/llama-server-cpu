# Define a build argument for the Ubuntu version to be used, defaulting to 22.04
ARG UBUNTU_VERSION=22.04

# Use the specified Ubuntu version as the base image for a common stage
FROM ubuntu:$UBUNTU_VERSION AS common

# Set frontend to noninteractive to suppress prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install necessary dependencies for building and running llama-server
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends libcurl4-openssl-dev libgomp1 curl  ca-certificates && \
    rm -rf /var/lib/apt/lists/*  # Clean up apt cache to reduce image size

# Create the build stage, starting from the common stage
FROM common AS build

# Define build arguments, used to control various GGML optimizations
ARG CMAKE_ARGS=

# Define a build date argument to be used later in the image metadata
ARG BUILD_DATE=

# Update package lists and install build dependencies like git, cmake, and build-essential
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends  build-essential git cmake && \
    rm -rf /var/lib/apt/lists/*  # Clean up apt cache to reduce image size

# Clone the llama.cpp repository from GitHub with a shallow clone (only the latest commit)
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# Set the working directory to the cloned llama.cpp repository
WORKDIR /llama.cpp

# Set environment variables for the build process, including the CMake arguments
ENV LLAMA_CURL=1 \
    CMAKE_ARGS=$CMAKE_ARGS

# Build the llama-server binary, using all available CPU cores, and strip symbols to reduce binary size
RUN echo "Building llama-server..." && \
    cmake -B build LLAMA_NATIVE=OFF -j$(nproc) llama-server > /dev/null 2>&1 && \
    strip ./llama-server && \
    echo "Done."

# Create the runtime stage, starting from the common stage
FROM common AS runtime

# Add metadata labels to the final image, including the image title, description, source, license, and creation date
LABEL org.opencontainers.image.title="llama-server-cpu" \
      org.opencontainers.image.description="A (cpu-only) docker image based on ggerganov/llama.cpp" \
      org.opencontainers.image.source="https://github.com/raoni-gabriel/llama-server-cpu" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created=$BUILD_DATE

# Set environment variables for runtime configurations of llama-server
ENV LC_ALL=C.utf8 \
    LLAMA_ARG_HOST=0.0.0.0 \
    LLAMA_ARG_CTX_SIZE=4096 \
    LLAMA_ARG_ENDPOINT_METRICS=1 \
    LLAMA_ARG_PORT=11434    

# Create a new user and group with ID 1000, and set the home directory for the user
RUN groupadd -g 1000 user && \
    useradd -u 1000 -g 1000 -m user

# Define a health check command to monitor the container's health by checking the health endpoint
HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]

# Expose port 11434 for llama-server to listen on
EXPOSE 11434

# Define the entry point for the container, specifying the llama-server binary
ENTRYPOINT [ "/llama-server" ]

# Copy the built llama-server binary from the build stage to the runtime stage, setting correct ownership for the user
COPY --from=build --chown=user:user /llama.cpp/llama-server /llama-server

# Run the container as the non-root user created earlier
USER user
