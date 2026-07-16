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
- **Large (n ≳ 200): Python is faster**, and it's the **BLAS, not the
  algorithm**. SciPy bundles multithreaded, CPU-tuned **OpenBLAS**; stock R
  ships single-threaded **reference** BLAS/LAPACK. `solve_sylvester` is
  dominated by the two Schur decompositions, so the quality of the underlying
  LAPACK/BLAS is what decides large-`n` speed.

### Making it fast at every size

This package links **whatever BLAS your R uses** (`$(BLAS_LIBS)`/`$(LAPACK_LIBS)`).
Point R at an optimized BLAS once and *every* matrix operation — including this
package — benefits, flipping the large-`n` result in R's favor:

- **OpenBLAS** or **Intel MKL** as a drop-in replacement for R's
  `Rblas`/`Rlapack` (or a threaded-BLAS R build).
- Note: R's built-in reference LAPACK **cannot** multithread; parallelism comes
  only from swapping the BLAS.

## License

MIT.
