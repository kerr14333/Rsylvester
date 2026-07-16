# sylvester

An R package (C++ / RcppArmadillo backend) that solves the **Sylvester matrix
equation**

$$A X + X B = Q$$

for the unknown matrix `X`, equivalent to
[`scipy.linalg.solve_sylvester`](https://docs.scipy.org/doc/scipy/reference/generated/scipy.linalg.solve_sylvester.html).
It handles **real and complex** matrices and **rectangular** `Q` (`A` is
`n×n`, `B` is `m×m`, `Q` and `X` are `n×m`).

## Installation

Requires a C++ toolchain (on Windows: **Rtools** matching your R version).

```r
# install.packages("remotes")
remotes::install_github("kerr14333/Rsylvester")
```

Or from a local clone:

```sh
R CMD INSTALL .
```

### Installing on different R versions (R ≥ 4.3)

The package builds on any R ≥ 4.3. The **only** thing that changes between R
versions on Windows is the matching **Rtools** toolchain — everything else in the
package is version-independent.

| R version | Rtools | download |
|-----------|--------|----------|
| 4.5.x | Rtools45 | <https://cran.r-project.org/bin/windows/Rtools/rtools45/> |
| 4.4.x | Rtools44 | <https://cran.r-project.org/bin/windows/Rtools/rtools44/> |
| 4.3.x | Rtools43 | <https://cran.r-project.org/bin/windows/Rtools/rtools43/> |

Steps for a given R version:

1. Install that R version and its matching Rtools from the table above (R finds
   Rtools automatically; no PATH setup needed for a standard install).
2. Install the package: `remotes::install_github("kerr14333/Rsylvester")` (or
   `R CMD INSTALL .` from a clone).

That's the whole story for the default build. To build the **optimized-BLAS**
variant instead, add the one `SYLVESTER_BLAS` environment variable at install
time (see [Using an optimized BLAS](#using-an-optimized-blas)). The optimized
BLAS itself (e.g. `C:\OpenBLAS`) is **shared across all R versions** — set it up
once and every R version can link against it; only Rtools must match the R
version.

On **Linux/macOS** there's no Rtools step — a standard C/C++ compiler is enough,
and the package links whatever BLAS your R already uses (often OpenBLAS already).

## Usage

```r
library(sylvester)

A <- matrix(rnorm(9), 3, 3)
B <- matrix(rnorm(4), 2, 2)
Q <- matrix(rnorm(6), 3, 2)

X <- solve_sylvester(A, B, Q)
max(abs(A %*% X + X %*% B - Q))   # ~ 1e-15, residual is ~0

# complex inputs work too (any complex arg promotes all three)
Ac <- A + 1i * matrix(rnorm(9), 3, 3)
Qc <- Q + 1i * matrix(rnorm(6), 3, 2)
Xc <- solve_sylvester(Ac, B, Qc)
```

`solve_sylvester(a, b, q)` mirrors SciPy's signature and argument meaning, and
returns `X` (complex if any input is complex).

## Algorithm

Both this package and SciPy use the **Bartels–Stewart** algorithm: Schur
decomposition of `A` and `B`, transform `Q`, solve the resulting (quasi-)
triangular system, transform back.

- **Real** inputs call Armadillo's `syl(A, B, -Q)`, backed by the same LAPACK
  `dtrsyl` routine SciPy uses — results agree to machine precision.
- **Complex** inputs use a direct Bartels–Stewart implementation: complex Schur
  decompositions `A = U R Uᴴ`, `B = V S Vᴴ`, then column-by-column
  back-substitution on `R Y + Y S = Uᴴ Q V`, and `X = U Y Vᴴ`.

A unique solution exists iff `A` and `−B` share no eigenvalue; otherwise the
triangular system is singular and an error is raised (matching SciPy's
`LinAlgError`).

## Correctness

The test suite (`tests/testthat/`) checks, across 14 matrix shapes (square,
tall, wide, `1×1`), for both real and complex inputs:

- **agreement with SciPy** — `scipy.linalg.solve_sylvester` is called in-process
  via `reticulate` and compared to the R result (`max|X_R − X_py| < 1e-9`);
- **residual sanity** — `‖A X + X B − Q‖ < 1e-8`, independent of SciPy.

All **88** assertions pass. The SciPy comparison auto-skips if
`reticulate`/`scipy` are unavailable, while the residual checks still run.

```r
testthat::test_local(".")
```

## Speed vs. Python

Median time per solve, `n×n` real matrices; "Python" is
`scipy.linalg.solve_sylvester` invoked from R through `reticulate` (how you'd
actually call it from R). Intel CPU, stock R 4.4.1 (reference BLAS), SciPy 1.18.

| n | `sylvester` (ms) | Python / reticulate (ms) | winner |
|----:|----------------:|-------------------------:|:-------|
| 5   | **0.031** | 0.229 | R **7.4×** |
| 10  | **0.069** | 0.269 | R **3.9×** |
| 25  | **0.330** | 0.565 | R **1.7×** |
| 50  | **1.66**  | 1.96  | R 1.2× |
| 100 | 11.95     | 12.06 | tie |
| 200 | 121.4     | **54.0**  | Python 2.2× |
| 400 | 804.2     | **264.9** | Python 3.0× |

**Takeaways**

- **Small/medium (n ≲ 100): this package is faster** — up to ~7× — because a
  native call avoids the Python-boundary (interpreter + array conversion) cost
  that dominates small problems.
- **Large (n ≳ 200): Python is faster with stock R**, and it's the **BLAS, not
  the algorithm**. SciPy bundles multithreaded, CPU-tuned **OpenBLAS**; stock R
  ships single-threaded **reference** BLAS/LAPACK. `solve_sylvester` is dominated
  by the two Schur decompositions, so the quality of the underlying LAPACK/BLAS
  is what decides large-`n` speed. Fixable — see below.

### With an optimized BLAS

Building this package against a multithreaded **OpenBLAS** (official v0.3.33,
DYNAMIC_ARCH; via `SYLVESTER_BLAS`, see below) closes the large-`n` gap and puts
R ahead at every size on the same machine:

| n | `sylvester` + OpenBLAS (ms) | Python / reticulate (ms) | winner |
|----:|--------------------------:|-------------------------:|:-------|
| 5   | **0.039** | 0.231 | R **5.9×** |
| 10  | **0.076** | 0.262 | R **3.4×** |
| 25  | **0.359** | 0.563 | R **1.6×** |
| 50  | **1.69**  | 1.94  | R 1.1× |
| 100 | **11.9**  | 12.1  | R ~tie |
| 200 | **57.0**  | 58.7  | R ~tie |
| 400 | 295.6     | 294.7 | dead tie |

Versus stock R that's roughly a **2× speedup at n = 200** (121 → 57 ms) and
**n = 400** (804 → 296 ms) — enough to match or beat Python across the board.
(Numbers depend on your CPU and OpenBLAS build; a well-threaded OpenBLAS or Intel
MKL matters most at large `n`.)

### Using an optimized BLAS

A quick note on terms: LAPACK (Schur decompositions, solves, factorizations)
runs on top of BLAS (matrix multiply and other kernels). So the thing to change
is the BLAS — swap R's default reference BLAS for an optimized one like OpenBLAS
or Intel MKL, and LAPACK speeds up along with it. This package uses whatever BLAS
R is configured with, so no rebuild is needed after the swap.

The R manual covers this in detail: *R Installation and Administration*,
§A.3 "Linear algebra" —
<https://cran.r-project.org/doc/manuals/r-release/R-admin.html#Linear-algebra>.

There are two ways to go about it: link an optimized BLAS into *this package
alone* at build time (no admin, R left untouched), or swap R's BLAS globally.

#### Option A: build this package against an optimized BLAS

`Makevars` honors an optional `SYLVESTER_BLAS` variable — set it to the linker
flags for your BLAS at install time, or leave it unset to use R's default.

PowerShell:

```powershell
$env:SYLVESTER_BLAS = "-LC:/OpenBLAS/lib -lopenblas"
R CMD INSTALL .
```

From R:

```r
install.packages(".", repos = NULL, type = "source",
                 configure.vars = c(sylvester = "SYLVESTER_BLAS=-LC:/OpenBLAS/lib -lopenblas"))
```

The OpenBLAS `libopenblas.dll` and its runtime deps (`libgfortran`,
`libgcc_s_seh`, `libquadmath`, `libwinpthread`) must be on `PATH` when R loads the
package. Only this package uses the optimized BLAS; R core is unchanged. Unset
the variable to fall back to R's own BLAS.

**Getting a multithreaded OpenBLAS on Windows** (one-time, shared by every R
version):

1. Download the LP64 x64 build from
   <https://github.com/OpenMathLib/OpenBLAS/releases> — e.g.
   `OpenBLAS-0.3.33-x64.zip` (the plain `x64` one, **not** `x64-64`, which is
   ILP64 and wrong for R).
2. Extract to `C:\OpenBLAS` (giving `C:\OpenBLAS\{bin,lib,include}`).
3. Add `C:\OpenBLAS\bin` to your PATH so the DLL loads at runtime:
   ```powershell
   [Environment]::SetEnvironmentVariable("Path",
     [Environment]::GetEnvironmentVariable("Path","User") + ";C:\OpenBLAS\bin",
     "User")
   ```
   The mingw runtime deps come from Rtools' `bin` (already on PATH for a normal
   Rtools install). Restart your shell/R afterward.
4. Install with `SYLVESTER_BLAS` set as shown above.

#### Option B: swap R's BLAS globally (Windows)

R keeps its BLAS in `Rblas.dll` under `<R_HOME>\bin\x64\` (e.g.
`C:\Program Files\R\R-4.4.1\bin\x64\`). Replacing that file with an optimized
build speeds up all of R, this package included. Since it lives under
`Program Files`, run these from an Administrator shell:

1. Back up the originals:
   ```bat
   copy Rblas.dll   Rblas.dll.ref
   copy Rlapack.dll Rlapack.dll.ref
   ```
2. Get an optimized `Rblas.dll`:
   - **OpenBLAS** — download a prebuilt Windows build from
     <https://github.com/OpenMathLib/OpenBLAS/releases> and rename its
     `libopenblas.dll` to `Rblas.dll`. Its runtime deps (`libgfortran`,
     `libgcc_s_seh`, `libquadmath`, `libwinpthread`) need to be on `PATH` —
     Rtools' `bin` dirs provide them.
   - **Intel MKL** — point `Rblas.dll` at MKL's `mkl_rt`; a bit more setup, and
     usually the fastest option on Intel CPUs.
3. Drop the new `Rblas.dll` into `bin\x64\` and restart R.
4. Check it took effect:
   ```r
   sessionInfo()   # BLAS / LAPACK paths appear at the bottom
   A <- matrix(rnorm(2000 * 2000), 2000)
   system.time(A %*% A)   # noticeably faster, and uses multiple cores
   ```
5. To revert, copy the `.ref` backups back over.

If you'd rather not touch the R install, a couple of options avoid the swap
entirely: install R through **conda** with an MKL-linked build
(`conda install r-base`), or use an R distribution that already bundles OpenBLAS.

The change is global — every R session and package uses the new BLAS, so
`sylvester` benefits automatically.

## License

MIT.
