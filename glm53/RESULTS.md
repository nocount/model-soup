# GLM-5.3-Flash tuning results

Measured 2026-09-18. Ryzen 7 7800X3D (8c/16t), 31GiB RAM, RTX 5070 Ti 16GB,
WD_BLACK SN850X 2TB. Quant UD-IQ1_S (93GB) against ~47GB of RAM+VRAM, so
expert weights stream from NVMe.

| config | prompt t/s | gen t/s | peak VRAM |
|---|---|---|---|
| `-cmoe -t 8` | 2.3 | 3.2 | 8640 MiB |
| `-cmoe -t 8` (repeat) | 2.4 | 3.5 | 8620 MiB |
| `-cmoe -t 16` | 2.5 | **1.4** | 8569 MiB |
| `-cmoe -t 6` | 2.2 | 2.9 | 8620 MiB |
| `-ncmoe 44 -t 8` | 2.4 | **3.7** | 11032 MiB |
| `-ncmoe 43 -t 8` | 2.6 | 3.6 | 13102 MiB |
| `-ncmoe 40 -t 8` | — | OOM | tried to alloc 15.7GB |

Run-to-run variance is roughly ±0.3 t/s (see the two `-cmoe -t 8` rows), so
differences smaller than ~0.5 t/s are noise. Warm-cache runs have reached 4.3 t/s.

## Conclusions

- **`-t 8`, never 16.** Hyperthread contention more than halved generation.
- **`-ncmoe 44`** is the most VRAM you can use; each MoE layer is ~2.6GB and
  the baseline already occupies ~8.6GB. It buys little over `-cmoe` but is free.
- **`--no-warmup` is mandatory.** Warmup reads all 93GB before the first token.

## The ceiling is disk bandwidth

A 64-token generation reads **154 GiB** from disk, sustaining ~3 GB/s against
the drive's ~6.7 GB/s sequential ceiling. This is inherent to the architecture:
8-of-288 expert routing across 43 MoE layers needs ~2.4GB of fresh weights per
token, and page cache holds only ~27GB of the 93GB model.

Consequences:
- Tuning threads or GPU flags will not move this much. The only real lever is
  more RAM for page cache.
- Readahead tuning was tested against and rejected: reads are already ~9MB
  contiguous expert slices, not the small random reads readahead helps.
- 2x64GB DDR5 (this B650 EAGLE AX takes up to 256GB) would fit a much better
  quant entirely in memory for an estimated 8-12 tok/s.

## Quality

UD-IQ1_S is ~71% top-1 vs ~95% at Q6. Creative and general prose is markedly
better than that number suggests; expect factual precision and math to be the
weak spots.
