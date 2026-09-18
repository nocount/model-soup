#!/usr/bin/env bash
# GLM-5.3-Flash (320B-A18B MoE) on RTX 5070 Ti 16GB + 31GB RAM.
# Weights stream from NVMe: ~3.5-4.3 tok/s generation, ~2.5 tok/s prompt.
# See README.md for why these flags are what they are.
set -euo pipefail

: "${GLM53_BIN:=/home/wil/llama-glm5/build/bin}"
: "${GLM53_MODEL:=/home/wil/models/glm53flash/UD-IQ1_S/GLM-5.3-Flash-UD-IQ1_S-00001-of-00003.gguf}"
: "${GLM53_CTX:=8192}"
: "${GLM53_PORT:=8080}"

[ -x "$GLM53_BIN/llama-cli" ] || { echo "llama-cli not found in $GLM53_BIN (set GLM53_BIN)" >&2; exit 1; }
[ -f "$GLM53_MODEL" ]         || { echo "model not found: $GLM53_MODEL (set GLM53_MODEL)" >&2; exit 1; }

COMMON=(
  --model "$GLM53_MODEL"
  -ngl 99              # all non-expert layers on GPU
  -ncmoe 44            # experts for layers 0-43 stream from disk; 44-45 pinned in VRAM
  -c "$GLM53_CTX"      # hybrid attention makes KV cheap (only every 4th layer has one)
  -t 8                 # physical cores only - 16 threads is ~2x SLOWER
  -fa on
  --no-warmup          # essential: warmup would read all 93GB before the first token
  --reasoning-effort low
  --temp 1.0 --top-p 0.95
)

case "${1:-chat}" in
  chat)  exec "$GLM53_BIN/llama-cli"    "${COMMON[@]}" ;;
  serve) exec "$GLM53_BIN/llama-server" "${COMMON[@]}" --host 127.0.0.1 --port "$GLM53_PORT" ;;
  *)     exec "$GLM53_BIN/llama-cli"    "${COMMON[@]}" -st -p "$*" ;;
esac
