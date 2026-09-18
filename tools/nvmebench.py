#!/usr/bin/env python3
"""Measure real disk read throughput with O_DIRECT, at block sizes that matter
for mmap-streaming model weights off NVMe.

Usage: python3 nvmebench.py <path-to-large-test-file>

Create the test file on the DRIVE YOU MEAN TO MEASURE:
    dd if=/dev/zero of=/home/wil/.cache/test.bin bs=1M count=8192 oflag=direct

Do NOT put it in /tmp - that is tmpfs (RAM) on this machine and will report
~16 GB/s and 770k IOPS at 4K, which is RAM speed, not disk. Sanity-check any
result against the drive's rated spec before trusting it.

Reference numbers, WD_BLACK SN850X 2TB on ext4:
    4K 0.08 GB/s | 64K 0.66 | 256K 2.09 | 1M 4.23 | 8M 6.58 | seq 6.69
"""
import os, mmap, random, time, sys
path = sys.argv[1]
size = os.path.getsize(path)
fd = os.open(path, os.O_RDONLY | os.O_DIRECT)

def bench(bs, n):
    buf = mmap.mmap(-1, bs)  # page-aligned
    offs = [random.randrange(0, (size - bs) // bs) * bs for _ in range(n)]
    t0 = time.perf_counter()
    got = 0
    for off in offs:
        got += os.preadv(fd, [buf], off)
    dt = time.perf_counter() - t0
    buf.close()
    return got / dt / 1e9, n / dt

print(f"{'block':>8} {'GB/s':>8} {'IOPS':>10}")
for bs, n in [(4*1024, 20000), (64*1024, 8000), (256*1024, 4000), (1024*1024, 2000), (8*1024*1024, 500)]:
    gbs, iops = bench(bs, n)
    label = f"{bs//1024}K" if bs < 1024*1024 else f"{bs//1024//1024}M"
    print(f"{label:>8} {gbs:>8.2f} {iops:>10.0f}")

# sequential
buf = mmap.mmap(-1, 8*1024*1024)
t0 = time.perf_counter(); got = 0; off = 0
while off + 8*1024*1024 <= size and got < 4e9:
    got += os.preadv(fd, [buf], off); off += 8*1024*1024
dt = time.perf_counter() - t0
print(f"{'seq':>8} {got/dt/1e9:>8.2f}")
os.close(fd)
