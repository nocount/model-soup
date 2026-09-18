#!/usr/bin/env bash
# Full tuning sweep for GLM-5.3-Flash. Results recorded in RESULTS.md.
# ncmoe below 43 OOMs a 16GB card (~2.6GB per MoE layer).
cd "$(dirname "${BASH_SOURCE[0]}")"
B=./bench.sh
echo "=== GLM-5.3-Flash UD-IQ1_S tuning sweep ==="
$B cmoe-t8      -ngl 99 -cmoe     -c 4096 -t 8  -fa on
$B cmoe-t16     -ngl 99 -cmoe     -c 4096 -t 16 -fa on
$B cmoe-t6      -ngl 99 -cmoe     -c 4096 -t 6  -fa on
$B ncmoe44-t8   -ngl 99 -ncmoe 44 -c 4096 -t 8  -fa on
$B ncmoe43-t8   -ngl 99 -ncmoe 43 -c 4096 -t 8  -fa on
$B ncmoe40-t8   -ngl 99 -ncmoe 40 -c 4096 -t 8  -fa on   # expected OOM
echo "=== sweep done ==="
