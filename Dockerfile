ARG UBUNTU_VERSION=22.04
ARG CMAKE_ARGS="-DGGML_CCACHE=OFF -DGGML_AVX=OFF -DGGML_AVX512=OFF -DGGML_AVX2=OFF -DGGML_FMA=OFF -DGGML_F16C=OFF"
ARG BUILD_DATE=
# ARG LLAMA_CPP_REVISION=

FROM ubuntu:$UBUNTU_VERSION AS common

RUN apt-get update && \
    apt-get install -y libcurl4-openssl-dev libgomp1 curl && \
    rm -rf /var/lib/apt/lists/*

FROM common as build

RUN apt-get update && \
    apt-get install -y build-essential git cmake && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

WORKDIR /llama.cpp
ENV LLAMA_CURL=1 \
    CMAKE_ARGS=$CMAKE_ARGS

RUN echo "Building llama-server..." && \
    make -j$(nproc) llama-server > /dev/null 2>&1 && \
    strip ./llama-server && \
    echo "Done."

FROM common AS runtime

ENV BUILD_DATE=${BUILD_DATE}
RUN test -n "$BUILD_DATE" || (echo "Build failed, BUILD_DATE is not set." && exit 1)
#    test -n "$LLAMA_CPP_REVISION" || (echo "Build failed, LLAMA_CPP_REVISION is not set." && exit 1)

LABEL org.opencontainers.image.title="llama-server-cpu" \
      org.opencontainers.image.description="A lightweight, CPU-only compiled image based on ggerganov/llama.cpp " \
      org.opencontainers.image.source="https://github.com/raoni-gabriel/llama-server-cpu" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.revision=$LLAMA_CPP_REVISION

ENV LC_ALL=C.utf8 \
    LLAMA_ARG_HOST=0.0.0.0 \
    LLAMA_ARG_CTX_SIZE=4096 \
    LLAMA_ARG_ENDPOINT_METRICS=1 \
    LLAMA_ARG_PORT=11434    

RUN groupadd -g 1000 user && \
    useradd -u 1000 -g 1000 -m user

HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]

EXPOSE 11434

ENTRYPOINT [ "/llama-server" ]

COPY --from=build --chown=user:user /llama.cpp/llama-server /llama-server

USER user
