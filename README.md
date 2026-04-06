<!--
    SPDX-License-Identifier: ISC
    SPDX-FileCopyrightText: Copyright © 2026 Lucca M. A. Pellegrini <lucca@verticordia.com>
    NOTE: File written with help from LLMs!
-->

# Artifact Repository for “A Quantitative Cache Evaluation of Select PolyBench Kernels”

This repository contains the full submission for the course “Arquitetura de
Computadores III” (Instituto de Ciências Exatas e Informática, Pontifícia
Universidade Católica de Minas Gerais), 2026/1, Prof. Matheus Alcântara Souza.

It packages a complete, reproducible pipeline to study cache hierarchy
sensitivities on a selected set of
[PolyBench](https://www.cs.colostate.edu/~pouchet/software/polybench/)
kernels using the [gem5](https://www.gem5.org) simulator. The pipeline is
expressed in a single [Zig](https://ziglang.org) build graph that: checks
host prerequisites; pins and bootstraps Python via pyenv; initializes and
builds the vendored gem5 submodule; compiles statically linked workloads; runs
an exhaustive, parameterized simulation sweep; generates figures; and builds
the final LaTeX report.

Target platform: Linux x86_64 only. While gem5 itself is portable, parts of the
automation (pyenv setup and LaTeX/report build) are written for Linux.


## Full Demonstration
[![asciicast](https://asciinema.org/a/Iqcv0OSyuDhDmM5C.svg)](https://asciinema.org/a/Iqcv0OSyuDhDmM5C?t=75)


## What’s Here

- [build.zig](build.zig): End-to-end build graph (Zig 0.15.2)
- [cache_config.py](cache_config.py): gem5 SE-mode system and cache
  configuration (CLI-tunable)
- [run_all_simulations.py](run_all_simulations.py): Orchestrates the full
  parameter sweep, with parallel workers and idempotent resumption
- [visualize_results.py](visualize_results.py): Turns `results/` into
  publication figures under `figures/`
- [analyze.zig](analyze.zig): Small helper to inspect/aggregate gem5 stats
  (optional)
- [workloads/](workloads/): C sources for PolyBench kernels and small
  microbenchmarks
  - atax.c, floyd-warshall.c, gemm.c, jacobi-2d.c, seidel-2d.c ([PolyBench v4.2.1](https://github.com/MatthiasJReisinger/PolyBenchC-4.2.1/) kernels)
  - array_stride.c, matrix_multiply.c, random_access.c (handwritten)
  - polybench.c (shared runtime)
- [include/polybench.h](include/polybench.h): PolyBench configuration header
- [report/](report/): IEEEtran paper sources; [report/main.tex](report/main.tex) is the manuscript
- [gem5/](https://github.com/gem5/gem5/tree/7a2b0e4): gem5 submodule (initialized by the build)


## Who Made This

See [AUTHORS](AUTHORS) for the full list and contact emails. If you use these
artifacts, please cite the work described in
[report/main.tex](report/main.tex). A machine-readable
[CITATION.cff](CITATION.cff) is provided.


## Summary Of The Experiment

- Workloads ([PolyBench v4.2.1](https://github.com/MatthiasJReisinger/PolyBenchC-4.2.1/)): atax, floyd-warshall, gemm, jacobi-2d, seidel-2d
- Core model: X86TimingSimpleCPU (in-order), 4 GHz; memory mode: timing; 8 GiB
  address space
- Cache hierarchy: private L1I/L1D, shared L2, shared L3 (see [cache_config.py](cache_config.py))
- Parameter sweep per workload (31 configs):
  - 11 realistic multi-level size presets (e.g., baseline i7-6700K; Ryzen;
    Apple; server)
  - cache line size ∈ {32, 64, 128, 256} bytes
  - associativity sweep for L1, L2, and L3 ∈ {1, 2, 4, 8, 16} (one level varied
    at a time)
- Total runs: 5 workloads × 31 configurations = 155 simulations
- Dataset sizes per kernel were chosen to balance fidelity vs. run time (see table below)

Dataset choices compiled into the real-run workloads:

| Kernel           | Dataset | Notes/Dimensions (from report)                    |
|------------------|---------|---------------------------------------------------|
| atax             | LARGE   | M=1900, N=2100                                    |
| gemm             | MEDIUM  | NI=200, NJ=220, NK=240                            |
| floyd-warshall   | SMALL   | N=180                                             |
| jacobi-2d        | MEDIUM  | N=250, T=100                                      |
| seidel-2d        | MEDIUM  | N=400, T=100                                      |


## Prerequisites (Linux)

Required (checked by `zig build check-deps`):
- [Zig 0.15.2](https://ziglang.org) ([ZVM](https://zvm.app) recommended)
- [GCC/G++ 15.2.1](https://gcc.gnu.org/) (used by gem5/m5 via
  [SCons](https://scons.org/))
- [pyenv](https://github.com/pyenv/pyenv) (the build pins Python to 3.14.3 inside gem5/venv)
- git, make
- A full [TeX Live](https://tug.org/texlive/) distribution to generate the report
- [Graphviz](https://graphviz.org/) (`dot` on PATH) to render gem5 `config.dot` to PDF (the Python binding `pydot` is installed via `requirements.txt`)

## Quick Start

Clone release tag with gem5 submodule (shallow clone recommended for saving disk space):

```bash
git clone https://github.com/lucca-pellegrini/AC3-TP1.git --branch=v0.1.0 --depth=1 --recursive --shallow-submodules
cd AC3-TP1
```

Sanity-check your host tools:

```bash
zig build check-deps
```

Reproduce everything end-to-end (very long: build gem5, run 155 sims, make figures, build the paper):

```bash
zig build report
```

The gem5 build usually takes ~50 minutes with decent parallelism, depending on
the hardware. The full simulations usually take hours to a few days, as the
build caps parallel workers to 9 to reduce OOM risks. Upon finishing, figures
and PDF report appear under `figures/` and `report/`.


## Incremental Workflow

![Running pipeline up to workload compilation from a fresh clone](demo/workload-compilation-demo.gif)

Each major step is addressable. You can run them individually and resume safely.

```bash
# 1) Prepare Python (pyenv + venv + pip install -r requirements.txt)
zig build setup-python

# 2) Initialize gem5 submodule
zig build init-gem5

# 3) Build gem5 simulator (gem5/build/ALL/gem5.opt)
zig build gem5

# 4) Build the m5 control library (libm5.a)
zig build m5

# 5) Build workloads (default step)
zig build

# 6) Run the full sweep for all 5 PolyBench kernels
zig build simulations

# 7) Generate publication figures from results/
zig build visualize

# 8) Build the LaTeX report
zig build report
```

All steps are idempotent. You can interrupt long runs and rerun the same step
later; remaining items will continue.


## Running One-Off Simulations

![Running all ATAx simulations with mini dataset using orchestrator](demo/atax-test-demo.gif)

You can run gem5 directly with a specific parameter and workload. Examples:

```bash
# Baseline config for jacobi-2d
./gem5/build/ALL/gem5.opt \
  -d results/jacobi-2d_baseline -- \
  cache_config.py ./zig-out/bin/jacobi-2d

# Try a different cache line size for atax
./gem5/build/ALL/gem5.opt \
  -d results/atax_cache_line_128 -- \
  cache_config.py --cache-line-size=128 ./zig-out/bin/atax

# Use a tiny debug binary (MINI dataset) to smoke-test the flow
./gem5/build/ALL/gem5.opt \
  -d results/seidel-2d_testline_64 -- \
  cache_config.py --cache-line-size=64 ./zig-out/bin/seidel-2d-test
```

Or invoke the orchestrator for just one workload:

```bash
# Run all 31 configs for gemm with 4 workers and CPU pinning (requires psutil)
./gem5/venv/bin/python run_all_simulations.py \
  --results-dir=results ./gem5/build/ALL/gem5.opt ./zig-out/bin/gemm \
  -j 4 --pin-workers

# Dry-run to see what would execute (no simulations are launched)
./gem5/venv/bin/python run_all_simulations.py \
  --dry-run --results-dir=results ./gem5/build/ALL/gem5.opt ./zig-out/bin/jacobi-2d
```


## Results Layout

Each simulation stores its outputs under `results/<workload>_<variant>/`. The
directory always contains `stats.txt` (the counters used by the analysis) and a
complete snapshot of the simulated system in `config.ini`, `config.json`, and
`config.dot` along with a rendered `config.dot.pdf`. When a run finishes, the
orchestrator drops a `.completed` marker so subsequent invocations can resume
cleanly without redoing work. The plotting stage reads all runs from
`results/`, writes publication figures to `figures/`, and the paper
([report/main.tex](report/main.tex)) imports those figures directly.


## Reproducibility Choices

To minimize drift, the build pins Python 3.14.3 via pyenv and installs all
Python tooling (SCons, plotting libraries, and friends) into `gem5/venv`.
The gem5 source is vendored as a Git submodule at a fixed commit and is always
built through that virtual environment’s SCons. Workloads target
`x86_64-linux-musl` and are linked statically to reduce host‑dependency
variance (see [musl](https://musl.libc.org)). The simulation runner is
deterministic and resumable; it caps parallelism at `min(9, nproc)` to avoid
oversubscription and out‑of‑memory failures.


## Licensing

Unless a file states otherwise, source code in this repository is licensed
under the [ISC license](LICENSE) (see the SPDX headers). The report
([report/main.tex](report/main.tex) and the figures it includes) is distributed
under [CC BY-SA 4.0](report/LICEENSE). The gem5 submodule remains under its own
upstream license, and the PolyBench workloads in [workloads/](workloads) remain
under the [Ohio State University Software Distribution
License](https://github.com/MatthiasJReisinger/PolyBenchC-4.2.1/blob/3e87254/LICENSE.txt).


## Citing

If you use the code, figures, or methodology, please cite the accompanying
paper in [report/main.tex](report/main.tex): A Quantitative Cache Evaluation
of Select PolyBench Kernels, Amanda Canizela Guimarães, Ariel Inácio Jordão,
Lucca Pellegrini, Paulo Dimas Junior, Pedro Vitor Andrade, ICEI/PUC Minas,
2026. Machine-readable citation metadata is available in
[CITATION.cff](CITATION.cff).
