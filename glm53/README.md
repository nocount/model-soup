# GLM-5.3-Flash, local

Running Z.ai's GLM-5.3-Flash (320B total / 18B active MoE, `glm5next` arch, 46
blocks, 288 experts with 8 active, 1M context, MIT licence) on a 16GB GPU with
31GB of RAM, by streaming expert weights off NVMe.

**~3.5-4.3 tok/s generation, ~2.5 tok/s prompt.** See [RESULTS.md](RESULTS.md).

## Run it

```bash
./glm53.sh chat                 # interactive
./glm53.sh serve                # OpenAI-compatible API on 127.0.0.1:8080
./glm53.sh "write me a haiku"   # one-shot
```

Paths are overridable: `GLM53_BIN`, `GLM53_MODEL`, `GLM53_CTX`, `GLM53_PORT`.
The first response after boot is slow until page cache warms.

## Two things that will bite you

**Ollama and mainline llama.cpp cannot load this model.** The `glm5_next`
architecture (hybrid linear/sparse attention with mHC) is not upstream. A stock
build fails on the unrecognised arch. You need Unsloth's branch.

**The smallest quant is 93GB**, against ~47GB of RAM+VRAM here. It only runs
because llama.cpp mmaps the weights and the NVMe is fast. Performance is bound
by disk bandwidth, not compute.

## Rebuilding the engine

Needs no `sudo` — `cmake`/`ninja` come from `uv`, and `-DLLAMA_CURL=OFF` avoids
the libcurl dev package. Assumes the CUDA toolkit is already installed.

```bash
uv tool install cmake && uv tool install ninja
export PATH="$HOME/.local/bin:$PATH" CUDACXX=/usr/local/cuda/bin/nvcc

git clone --branch glm5next/upstream --depth 1 \
  https://github.com/unslothai/llama.cpp ~/llama-glm5

cmake -B ~/llama-glm5/build -S ~/llama-glm5 -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=120 \
  -DLLAMA_CURL=OFF -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=ON

cmake --build ~/llama-glm5/build -j 16 \
  --target llama-cli llama-server llama-gguf-split llama-bench
```

`CMAKE_CUDA_ARCHITECTURES=120` is Blackwell (RTX 50-series); cmake promotes it
to `120a`. Change it for other cards — building all architectures is far slower.
CUDA 13.3 accepts gcc 15.2 as host compiler. Two build warnings are harmless:
NCCL missing (single GPU) and OpenSSL missing (disables HTTPS in the bundled
server). The `llama-server` browser UI asset fails to download; the API and
`llama-cli` are unaffected.

## Fetching weights

```bash
uv tool install huggingface_hub
hf download unsloth/GLM-5.3-Flash-GGUF --include "UD-IQ1_S/*" \
  --local-dir ~/models/glm53flash --max-workers 8
```

93GB in 3 shards; point `GLM53_MODEL` at shard `00001-of-00003`, llama.cpp
finds the rest. Other quants in that repo run 97GB (IQ1_M) to 292GB (Q6_K_XL) —
[the table](https://unsloth.ai/docs/models/glm-5.3-flash) lists accuracy per size.

## Benchmarking

```bash
./sweep.sh                                         # full config sweep
./bench.sh mylabel -ngl 99 -ncmoe 44 -c 4096 -t 8 -fa on   # one config
python3 ../tools/nvmebench.py /path/to/8GB/testfile         # disk ceiling
```
