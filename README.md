# llama-server-cpu
A (cpu-only) docker image based on [ggerganov/llama.cpp](https://github.com/ggerganov/llama.cpp)

Think of it as a lightweight version of [ollama](https://ollama.com/), providing an easy way to run GGUF models locally. 

# Features
* This image has 5 increasing "tiers", each one compiled specifically for a given CPU instruction set, as follows:

- t0 = No CPU optimizations. Should run even on old computers
- t1 = AVX is enabled
- t2 = AVX, AVX2 are enabled
- t3 = AVX, AVX2, AVX512 are enabled
- t4 = AVX, AVX2, AVX512, F16C are enabled

* The images will be tagged accordingly: **t0-latest**, **t1-latest** and so on. Therefore there wil be **NO** image tagged as "latest", you must pick one of the tiers based on your what features CPU supports. Remmember to pick the higher tiers, because the inference speed of the models will be enhanced.

* It runs on port 11434, the same used by ollama to ease compatibility.

* It features a small, chat UI courtesy of llama.cpp on [http://localhost:11434](http://localhost:11434)

* It runs with user/group id 1000 named "user". This eases compatibility with [Project IDX](https://idx.dev/) and also with bind-mounts for most common Linux distributions.

* It features health checks

* It can download model files (GGUF) automatically from the internet by using **LLAMA_ARG_MODEL_URL** (see the running example bellow)

* Models can be cached locally if you "bind-mount" the models **/home/user/.cache/llama.cpp/** folder

---
# Running

```
docker run -d -p 11434:11434 -e LLAMA_ARG_MODEL_URL=https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf --name qwen25_3B ghcr.io/raonigabriel/llama-server-cpu:t0-latest
```

or using docker-compose:

```
services:
  qwen25_3B:
    image: ghcr.io/raonigabriel/llama-server-cpu:t0-latest
    container_name: qwen2.5_3B
    ports:
      - "11434:11434"
    environment:
      - LLAMA_ARG_MODEL_URL=https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf
    restart: unless-stopped
```

# FAQ
Q: Where are the docker images served from?

A: I will be using Github Container Registry (ghcr.io). Images from DockerHub are **not** created by me.

Q: Are you one of the developers of llama.cpp?

A: No, I have **NO** association of any kind with llama.cpp, but  do love their software. Just took it, compiled and provided a standalone, lightweight, easy to use docker image.

Q: Are you one of the developers of ollama?

A: No, I have **NO** association of any kind with ollama. It is a wonderfuill product allowing end-users, developers and SMB to harness the power of LLMs  - and I have used it for quite some time.

Q: Why did you create this?

A: Because their [ollama](https://github.com/ollama/ollama), [LocalAI](https://github.com/mudler/LocalAI) images are bloated (>=3GB) while mine is about 62MB. There are a few reasons why they get so big:
1) Their images automatically detect wich specific instructions your CPU supports and then use a precompiled version (dynamic loading) designed for it. That way, they need to pack every possibility of instruction set, hence increasing the size of the image.
2) Some of their images migh have compiled CUDA support. also increasing the size.
3) Their image may include python, ffmpeg, libs and extra software.
4) Their image might offer extra features (image generation, audio transcription)
5) Some of their image have "default models" already loaded into it
6) I strip debugging symbols from the binary
7) My image is baed on Alpine instead of Ubuntu

Q) What [quantized](https://huggingface.co/docs/optimum/concept_guides/quantization#quantization) versions of the models do you recommend?

A) Usually, "Q4_K_M" versions offers a good balance between speed and accuracy.

Q) How do I create a custom image for a specific model?

A) Simple as setting an environment variable. If you need to install extra software (eg. python), you need to change the user back to "root" then back to "user"
```
FROM ghcr.io/raonigabriel/llama-server-cpu:t0-latest
ENV LLAMA_ARG_MODEL_URL=https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf

USER root
RUN apk add --no-cache py3-pip py3-virtualenv
USER user
```

Q) How do I create a custom image that pre-packages a specific model?

A) Just download the model and put it into the cache **/home/user/.cache/llama.cpp/** folder.

Q) My inference speed is not good: model takes a lot time to answer.

A) Try using a higher tier like t5 (if your CPU supports it) or try using a small model instead, with less parameters. The [Qwen2.5](https://huggingface.co/collections/Qwen/qwen25-66e81a666513e518adb90d9e) series of models do offer plenty options for you to pick: 0.5B, 1.5B, 3B, 7B, 14B, 32B, 72B paramers. Just remember that you will **never** get the same performance level as if running models on GPU / TPU / NPU.

Q) What about security?

A) The image is based on Alpine and designed to be minimal (fewer moving parts = less attack exposure) and to run as a separate user with **no** root powers.

Q) Is there a way to protect the endpoints by using some sort of auth?

A) Yes, by adding the **LLAMA_API_KEY** env var like so:
```
services:
  qwen25_3B:
    image: ghcr.io/raonigabriel/llama-server-cpu:t0-latest
    container_name: qwen2.5_3B
    ports:
      - "11434:11434"
    environment:
      - LLAMA_ARG_MODEL_URL=https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf
    restart: unless-stopped
      - LLAMA_API_KEY="sk-my-secret-api-key"
```

Q) Do you have an arm64 version?

A) Not yet, but it is planned. Meanwhile, if you are on a MAC, try googling for a "METAL" version of llama-cpp.
