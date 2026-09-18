#!/usr/bin/env bash
# Benchmark one GLM-5.3-Flash offload config. Usage: ./bench.sh <label> [llama-cli flags...]
# Reports generation/prompt tok/s and peak VRAM.
set -uo pipefail

: "${GLM53_BIN:=/home/wil/llama-glm5/build/bin}"
: "${GLM53_MODEL:=/home/wil/models/glm53flash/UD-IQ1_S/GLM-5.3-Flash-UD-IQ1_S-00001-of-00003.gguf}"
: "${LOGDIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../logs}"
mkdir -p "$LOGDIR"

LABEL="$1"; shift
LOG="$LOGDIR/bench-${LABEL}.log"
VRAM="$LOGDIR/vram-${LABEL}.txt"

# sample VRAM for the duration of the run
( while :; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; sleep 1; done ) > "$VRAM" 2>/dev/null &
SAMPLER=$!
trap 'kill $SAMPLER 2>/dev/null' EXIT

/usr/bin/time -f "wall=%es maxrss=%MkB" "$GLM53_BIN/llama-cli" --model "$GLM53_MODEL" \
  --no-warmup -st --reasoning-effort low --temp 1.0 --top-p 0.95 \
  -n 64 -p "Explain in three sentences why the sky appears blue." \
  "$@" > "$LOG" 2>&1

kill $SAMPLER 2>/dev/null
PEAK=$(sort -n "$VRAM" 2>/dev/null | tail -1)
RATE=$(grep -oE "Prompt: [0-9.]+ t/s \| Generation: [0-9.]+ t/s" "$LOG" | tail -1)
WALL=$(grep -oE "wall=[0-9.]+s" "$LOG" | tail -1)
printf "%-22s %-46s peakVRAM=%sMiB %s\n" "$LABEL" "${RATE:-FAILED}" "${PEAK:-?}" "$WALL"
