<!--
    SPDX-License-Identifier: ISC
    SPDX-FileCopyrightText: Copyright © 2026 Lucca M. A. Pellegrini <lucca@verticordia.com>
    NOTE: File written with help from LLMs!
-->

# Notes on the Report: What the 8-Page Limit Forced Us to Compress or Omit

This directory holds the sources of the paper “A Quantitative Cache Evaluation
of Select PolyBench Kernels” ([main.tex](main.tex), [references.bib](references.bib)),
written against the [SBC conference template](sbc-template.sty) for
SSCAD-WIC. The venue imposes a hard limit: the text body, including the
acknowledgments and everything before the reference list, must fit in **eight
A4 pages at 12 pt**. The camera-ready version answers three reviews, and
answering them properly required adding material (a corrected analytical
model, a predicted-vs-measured comparison, memory-model details, determinism
evidence, six new references, and an explicit discussion of core-model
realism). Every line added had to be paid for by a line removed.

This file records, for readers and for ourselves, what was compressed, what
was dropped, and which supporting numbers did not make it into the paper. The
manuscript has none of this slack; this file does. Nothing here contradicts
the paper; it is the long version of it.

## How Tight It Was

- The accepted version already filled exactly eight pages, with the reference
  list starting at the top of page 9.
- Addressing the reviews, before any cutting, pushed the body to roughly 9.5
  pages. Reaching eight again took six successive rounds of tightening.
- The final PDF is ten pages: eight of body and acknowledgments, two of
  references. The reference list grew from 13 to 18 entries and is not
  counted against the limit.
- Trimming was done paragraph by paragraph, favoring removal of restatement
  over removal of evidence. Where a claim and its supporting number competed
  for space, the number stayed and the prose around it was cut.

## What Was Compressed

### Abstract and resumo

Both were trimmed to roughly ten lines, the template’s nominal length. The
first sentence was rewritten after Reviewer 1 noted that the original did not
state what was being proposed. The Portuguese resumo mirrors the English
abstract sentence by sentence; nothing is said in one that is not in the other.

### Introduction

- The “remainder of this paper is organized as follows” roadmap paragraph was
  removed entirely. Section headings carry that information.
- The four-item bulleted list of contributions became a single sentence with
  three numbered clauses. The fourth bullet (null results) was folded into the
  third.
- The repository citation moved from the bibliography to a footnote, as
  Reviewer 1 suggested, with an explicit statement that one command re-derives
  every number and figure. The bibliography entry `repo:2026` was deleted.
- First-level caches (L1I, L1D) and the last-level cache (LLC) are now defined
  on first use, also per Reviewer 1.

### Related work

The section was rewritten from scratch to answer the “bibliography is weak”
and “cannot establish a gap from three papers” criticisms. Six references were
added: Smith (1987) on line size, Hill and Smith (1989) on associativity,
Cantin and Hill (2001) on cross-benchmark miss ratios, Hennessy and Patterson
(2019) for the memory-stall CPI decomposition, Williams et al. (2009) for
Roofline, and Gholami et al. (2024) as a current citation of the memory wall.
The three original references (Khoshavi and DeMara 2018, Bueno et al. 2024,
Shahid et al. 2025) were kept but compressed from two paragraphs to about
seven lines.

What did not fit: a fuller account of how Smith’s empirical line-size fit and
his “mean delay per reference” model relate to our Eq. 1; a comparison with
Przybylski, Horowitz, and Hennessy (1989) on performance-optimal multi-level
hierarchies, which is the natural precedent for sweeping capacity per level;
and any discussion of gem5-based cache studies on PolyBench specifically,
which we could not survey adequately in the space available.

### Methodology

- Section 3.1 lost the sentence explaining that the direct-mapped case “proves
  to be the sole associativity setting with a measurable effect”; that fact is
  stated in Section 4.3 instead.
- The paragraph on the Zig build graph was cut from eight lines to four. The
  orchestrator’s worker pool, CPU pinning, completion markers, and resumability
  are no longer described in the paper; see the [main README](../README.md).
- The `f_stall` definition is given inline rather than as a displayed equation.
- Table 1 (cache presets) was reformatted from two preset columns to three,
  with sizes abbreviated as `32K`, `8M`, and so on, to save two rows.
- The workload paragraph was rewritten to describe the actual 4.2.1 loop
  structures (see “Corrections” below), which made it longer, so the sentence
  about datasets being reduced iteratively was shortened to one clause.

### Results

- Table 3 was restructured after Reviewer 1 reported difficulty reading it.
  Each column now has a two-line header stating exactly what it measures, the
  best capacity preset is named per row, and a “predicted” column was added
  for the line-size speedup. Its caption still had to be cut by two lines.
- Figure 1 (L1D miss rate and IPC versus line size) was kept, per the choice
  made when the page budget ran out, but regenerated as a single compact
  two-panel figure (`figures/compact_cache_line.pdf`, produced by
  `create_cache_line_compact_figure()` in
  [visualize_results.py](../visualize_results.py)). The original two separate
  3.45 x 2.5 in panels, scaled to fit a one-row slot, had illegible axis text.
- A planned Table 4, “where L1D misses are served and mean L1D miss latency per
  line size”, was written, typeset, and then removed; its contents were folded
  into two sentences of Section 4.2. The table is reproduced below.
- The dataset-size confound paragraph at the end of Section 4.4 was merged
  into the preceding paragraph, and the instruction-cache null result was
  reduced from a paragraph to two sentences.
- The observation that gemm’s direct-mapped L2 is faster than the 8-way LRU
  one survived, but only as one sentence.

### Conclusion

The two conditions of the criterion are now stated in one sentence instead of
an enumerated pair, and the limitations paragraph, though expanded in scope to
cover Reviewer 2’s points (simplified core, disabled prefetching, regular
workloads), was tightened word by word.

## What Was Omitted Outright

The following material was prepared for the revision and does not appear in
the paper in any form.

### Mean L1D miss latency and miss source per line size (the dropped Table 4)

Reviewer 3 asked for average miss latency and total traffic versus line size.
The paper gives these numbers in prose; here is the table.

| Kernel         | L1D misses served by (baseline)         | 32 B | 64 B | 128 B | 256 B |
| -------------- | --------------------------------------- | ---: | ---: | ----: | ----: |
| atax           | DRAM (lines of A), L2 (second row pass) |  115 |  112 |   117 |   159 |
| jacobi-2d      | L3                                      |   80 |   80 |    80 |    80 |
| gemm           | L3 (B exceeds L2)                       |   80 |   80 |    80 |    80 |
| seidel-2d      | L3 (reads), L2 (write upgrades)         |   46 |   46 |    46 |    46 |
| floyd-warshall | L2 (fits entirely)                      |   26 |   26 |    26 |    26 |

Latencies are mean cycles per L1D miss, `dcache.overallMissLatency / 250 /
dcache.overallMisses`, from the ROI statistics block. DRAM traffic in the ROI
is 38.5 MiB for atax at every line size (32.0 MiB read, 8.4 MiB written back;
the writebacks are dirty lines of A left by initialization) and at most 2 KiB
for the other four kernels.

Seidel-2D’s 46-cycle mean is the average of two populations: 2.0 M read misses
at 80 cycles (served by L3) and 1.99 M write misses at 12 cycles, which are
not fetches at all but coherence upgrades of lines already present in Shared
state, served by L2. The paper calls these “write upgrades” without further
explanation.

### `f_stall` at every line size, and the exact identity behind Eq. 1

The paper reports `f_stall` only at the 64-byte baseline. The full sweep:

| Kernel         | f_stall 32 B | 64 B   | 128 B  | 256 B  | Non-stall cycles, 256 B / 32 B |
| -------------- | -----------: | -----: | -----: | -----: | -----------------------------: |
| atax           |       0.1687 | 0.0896 | 0.0500 | 0.0351 |                         1.0061 |
| jacobi-2d      |       0.0742 | 0.0384 | 0.0196 | 0.0099 |                         1.0035 |
| gemm           |       0.0654 | 0.0337 | 0.0171 | 0.0086 |                         1.0031 |
| seidel-2d      |       0.0275 | 0.0139 | 0.0070 | 0.0035 |                         1.0021 |
| floyd-warshall |       0.0071 | 0.0036 | 0.0018 | 0.0009 |                         1.0010 |

The last column is the direct check that non-stall time is independent of the
cache configuration: `(numCycles - stallCycles)` at 256 B divided by the same
quantity at 32 B. The paper summarizes this as “less than 0.7%”.

Eq. 1 in the paper, `speedup = (1 + f) / (1 - 0.75 f)` with `f` the baseline
`f_stall`, is Amdahl’s law applied at the 32-byte end: the stalled fraction
there is `f32 = 2f / (1 + f)` (stall time doubles when misses double, while
non-stall time is fixed), and the stalled part speeds up by 8x from 32 to
256 B, so `speedup = 1 / ((1 - f32) + f32/8)`. The algebra reduces to the
form in the paper; there was no room to show it.

### What was wrong with the original model

The accepted version claimed that `1 / (1 - k f_stall)` with `k = 0.875`
“predicts every measured speedup to within 1.8 percentage points”. Reviewer 3
correctly observed that this does not reproduce: with `f_stall` at 64 B it
gives +8.5% for atax against a measured +15.4%, and +3.4% against +6.6% for
Jacobi-2D. The error was ours: `k = 0.875` is the fraction of misses
eliminated between 32 and 256 B, so the stalled fraction in that formula must
also be the one at 32 B, not at the 64 B baseline. Using `f32` directly gives
+17.3% for atax (1.9 points high); deriving `f32` from the baseline as above
gives +16.8% (1.4 points high) and within 0.3 points for the other four. The
paper reports the latter and does not describe the original mistake.

### Why atax over-predicts by 1.4 points

The constant-latency assumption fails only for atax, whose misses reach DRAM.
A 256-byte line is four DDR3 bursts of 64 B (each `tBURST = 5 ns`, i.e. 20
cycles at 4 GHz) and eight 32-byte beats on each crossbar. The measured mean
miss latency rises from 112 to 159 cycles, so the stalled part speeds up by
less than 8x. Using the measured per-size latencies instead of a constant
reproduces the measured speedup within the 0.6% non-stall drift.

### Core-model realism (Reviewer 3’s CPI concern) in numbers

TimingSimpleCPU is unpipelined. Each instruction costs, roughly, one L1I hit
(4 cycles) to fetch, one cycle per micro-op to execute, and one L1D hit
(4 cycles) per memory access. The table shows the measured baseline CPI, the
CPI with all L1D miss latency subtracted, and the estimate from that
accounting.

| Kernel         | CPI  | Non-stall CPI | Micro-ops/inst | L1D accesses/inst | 4 + uops + 4 x accesses |
| -------------- | ---: | ------------: | -------------: | ----------------: | ----------------------: |
| atax           | 7.26 |          6.61 |           2.00 |             0.229 |                    6.91 |
| jacobi-2d      | 7.05 |          6.78 |           1.98 |             0.175 |                    6.68 |
| gemm           | 6.92 |          6.69 |           1.93 |             0.256 |                    6.95 |
| seidel-2d      | 6.57 |          6.48 |           1.90 |             0.134 |                    6.43 |
| floyd-warshall | 6.75 |          6.73 |           1.84 |             0.276 |                    6.95 |

The estimate ignores branch and micro-op scheduling details, but it accounts
for the magnitude: CPI near 7 is the core model, not the memory system. The
paper states the conclusion (6.5–6.8 cycles of fixed overhead per instruction)
without this table. The consequence spelled out in the paper is important and
easy to misread: because that overhead inflates the denominator of every stall
fraction, the absolute sensitivities reported are *smaller* than a pipelined
in-order core with CPI near 1 would show, and *larger* than an out-of-order
core that overlaps misses would show. The accepted version called them “upper
bounds”, which was only half right; the revision no longer does.

### Memory-level parallelism

Reviewer 3 pointed out that TimingSimpleCPU blocks on demand misses, so the
accepted version’s claim that MSHRs admit limited memory-level parallelism was
wrong. The revision says so directly, with the measured evidence: the memory
controller’s average read-queue length at enqueue (`mem_ctrl.avgRdQLen`) is
exactly 1.00 in every one of the 155 runs. The MSHR counts (8 at L1, 20 at L2,
40 at L3, with `tgts_per_mshr` 20/12/12) remain in [cache_config.py](../cache_config.py)
and in every run’s `config.ini`; they are simply never contended.

### DRAM model details

The paper lists the DRAM model (`DDR3_1600_8x8` behind one `MemCtrl`), channel
width, rank and bank counts, `tCL = tRCD = tRP = 13.75 ns`, FR-FCFS
scheduling, and the open-adaptive page policy. Omitted: `tRAS = 35 ns`,
`tRFC = 260 ns`, `tREFI = 7.8 us`, burst length 8, 8-bit devices with 8 devices
per rank, address mapping `RoRaBaCoCh`, a 1 KiB row buffer per device, and
16 minimum writes per read-to-write switch. For atax at baseline the
controller reports a mean access latency of 25.7 ns per burst (103 cycles) and
0.62% data-bus utilization; for the other kernels the ROI issues fewer than
50 DRAM requests. All of this is in `results/<run>/config.ini` and
`stats.txt`.

### Associativity: the per-level data behind “flat”

| Kernel         | L1D miss-rate increase, direct-mapped vs 8-way | IPC gain, 1-way to 8-way L1 | IPC spread, 2- to 16-way (max over L1/L2/L3) |
| -------------- | ---------------------------------------------: | --------------------------: | -------------------------------------------: |
| atax           |                                          +3.3% |                      +0.09% |                                       0.179% |
| jacobi-2d      |                                         +19.4% |                      +0.21% |                                       0.000% |
| gemm           |                                         +30.9% |                      +0.29% |                                       0.003% |
| seidel-2d      |                                         +11.3% |                      +0.08% |                                       0.000% |
| floyd-warshall |                                         +96.0% |                      +0.29% |                                       0.001% |

The one non-flat L2 result is gemm: a direct-mapped L2 is 0.54% *faster* than
8-way LRU. Matrix B (422 KiB) is streamed cyclically through the 256 KiB L2
once per row of C; under LRU every line is evicted just before it is reused
(5,489 L2 hits in the whole run), whereas a direct-mapped cache keeps whichever
subset of lines happens not to collide (313,831 hits). This is the textbook
LRU pathology for cyclic access slightly larger than the cache, and it earned
one sentence in Section 4.3.

### Capacity: per-preset results not in the paper

Only the best preset per kernel and the one negative result are in Table 3.
The worst preset is Small Embedded for every kernel: Seidel-2D −3.06%, atax
−0.41%, gemm −0.05%, Jacobi-2D and Floyd-Warshall 0.00%. The i9-9900K preset
(16 MiB L3, otherwise identical to baseline) gives exactly 0.00% for every
kernel, including atax, which is the non-monotonicity discussed in
Section 4.4. Full per-preset figures for every kernel are under
[`../figures/`](../figures/).

### Determinism: what exactly was compared

The paper says each configuration was run once, that the six physically
identical baseline configurations per kernel (the explicit baseline, the
`baseline` size preset, the 64-byte line, and the 8-way L1, 8-way L2, and
16-way L3 settings) are bit-identical, and that a second execution of the full
sweep on another host reproduces instruction counts exactly, L1D miss counts
to 0.01%, and cycle counts to 3 x 10^-5. Details that were cut:

- The second sweep is the one preserved under [`results/`](results/) in this
  directory, from an earlier run on a different machine (`cwd` in its
  `config.ini` files is `/home/build/AC3-TP1`); the primary sweep is the
  top-level `results/`.
- Across all 155 pairs, `simInsts` is identical and IPC agrees to within
  4 x 10^-6 (i.e. to the four decimals the paper reports). `numCycles`
  differs by at most 62,033 cycles out of 2.0 x 10^9, relatively 3.1 x 10^-5
  (atax under the Apple M2 preset). L1D miss counts differ by at most 22 (out
  of 3.6 x 10^5, for floyd-warshall under Small Embedded); L1I misses by at
  most 2. The largest absolute disagreement is in deeper-level miss counts
  whose totals are themselves in the hundreds: 486 versus 337 L3 misses for
  jacobi-2d under Small Embedded, 383 versus 406 L2 misses for floyd-warshall
  under the same preset. These are negligible against the millions of L1D
  accesses but are not zero, which is why the paper does not say
  “bit-identical” for the cross-host comparison.
- The likely cause is the unpinned C toolchain (GCC >= 14): a binary that is
  instruction-count identical but laid out differently in memory would change
  which few hundred lines conflict in a 1 MiB L3, without changing anything
  else. gem5 itself is at a fixed commit. We did not verify this hypothesis.
- Nothing in the pipeline sets or consumes a random seed. gem5’s SE mode with
  this CPU model is deterministic by construction.

### Instruction-cache statistics

The accepted version said the L1I “never exceeded 78 misses (<= 0.34 MPKI) in
any run”. Both numbers were wrong: the maximum over all 155 runs is 44 misses
(jacobi-2d at 32 B lines), and 44 misses in 9.2 x 10^8 instructions is
5 x 10^-5 MPKI, three orders of magnitude below the stated figure. The
revision states 44 misses and omits the MPKI.

## Corrections to the Accepted Text

Two descriptions of the kernels in the accepted version did not match the
PolyBench 4.2.1 sources that were actually simulated. Reviewer 1 asked for a
better discussion of access patterns, and checking the code against the
statistics exposed both.

- **atax** was described as “combining row-major streaming with column-wise
  accesses”. In 4.2.1 both phases are row-major: for each row `i`, the kernel
  computes `tmp[i] = A[i][:] . x` and then `y[:] += tmp[i] * A[i][:]`. The
  same row is streamed twice in succession. The statistics confirm it: L2
  misses (499,531) match the number of 64-byte lines in A (498,750) to 0.2%,
  so each line of A is fetched from DRAM exactly once, and L1D misses are
  about 3.3x that, the second pass re-missing in L2 because a 16.8 KiB row plus
  the two 16.8 KiB vectors exceed the 32 KiB L1D.
- **gemm** was described as reusing “the C[i][j] accumulator across the
  k-reduction”. That is the i-j-k loop order; 4.2.1 uses i-k-j, in which the
  inner loop streams `C[i][:]` and `B[k][:]` contiguously with `A[i][k]`
  invariant. The 1.7 KiB row of C stays in L1D across the whole k-loop, and
  matrix B (422 KiB, larger than the 256 KiB L2) is re-streamed from L3 for
  every i. The statistics confirm this too: L2 misses (1,331,514) are within
  1% of `NI x (lines of B) = 200 x 6,600`.

Neither correction changes any measured number or any conclusion; both change
the mechanism offered for gemm’s and atax’s line-size response, and the
revised Section 4.2 is built on the corrected descriptions.

## Reviewer Requests Deferred to Future Work

These were raised in the reviews, are acknowledged in Section 5, and are not
addressed by new experiments in this revision:

- An out-of-order core (Reviewer 2, Reviewer 3), to test Eq. 1 where stalls
  overlap. The paper now states explicitly that the absolute magnitudes are
  specific to the blocking core.
- A pipelined in-order core, which would reduce the fixed per-instruction
  overhead and enlarge every stall fraction.
- Prefetching enabled (Reviewer 2), which on real hardware recovers part of
  the spatial locality that line size exploits.
- Irregular or pointer-chasing workloads (Reviewer 2), where conflict misses
  and associativity may matter.
- Larger datasets, so that more than one kernel crosses the LLC threshold.

The pipeline makes each of these a one-line change to
[cache_config.py](../cache_config.py) or [build.zig](../build.zig) followed by
`zig build report`; the obstacle is simulation time, not tooling.

## Building

See the [main README](../README.md) for the full pipeline. To rebuild only the
PDF after editing [main.tex](main.tex) or [references.bib](references.bib),
with figures already present under `../figures/`:

```bash
# from the repository root
zig build report
# or, inside report/, using the vendored latexrun driver
just all
```

The build embeds [main.tex](main.tex) and [references.bib](references.bib)
inside the PDF as file attachments, so the sources travel with the document.
