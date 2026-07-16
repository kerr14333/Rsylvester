# Cross-version R checks (Docker)

Runs `R CMD check --as-cran` on the `sylvester` package across several R
versions in `rocker/r-ver` containers, so we don't depend on the two R
installs on the host machine. The package's own tests
(`tests/testthat/test-basic.R`) are self-contained — residual and closed-form
checks with no external dependency.

## Run

Requires Docker Desktop running.

```powershell
# Windows (PowerShell)
./docker/run-matrix.ps1                      # default: 4.2.3, 4.3.3, 4.5.1
./docker/run-matrix.ps1 -Versions 4.3.1,4.5.1
```

```bash
# bash
docker/run-matrix.sh                         # default: 4.2.3 4.3.3 4.5.1
docker/run-matrix.sh 4.3.1 4.5.1
```

Per-version logs land in `docker/logs/R-<ver>.log` (gitignored). A summary
table prints at the end; the runner exits non-zero if any version fails.

`check.sh` runs the full `R CMD check --as-cran`, PDF reference manual
included (the image installs LaTeX for this). So each run is both the
cross-version compatibility gate and a CRAN-readiness gate: on supported R
versions the package checks with **0 ERRORs, 0 WARNINGs**.

This does not replace CRAN's own multi-platform run. Before an actual
submission still check Windows + macOS + r-devel via win-builder
(`devtools::check_win_devel()`), mac-builder, and R-hub.

## Expected vs. actual results

`DESCRIPTION` declares `Depends: R (>= 4.3.0)`. The floor was chosen
empirically: the package was probed on R 4.0.5 / 4.2.3 / 4.3.3 / 4.5.1 and
checks **100% clean (0 WARNINGs)** from 4.2.3 up; 4.3.0 is the conservative,
fully-verified minimum. (It also builds and passes its tests on 4.0.x — only
the PDF manual there tripped over a missing LaTeX macro in the container, not
a package defect.)

| R version | Expected | Actual (2026-07-15) | Notes |
|-----------|----------|---------------------|-------|
| 4.2.3 | CHECK-FAIL | **CHECK-FAIL** (1 ERROR) | Below the floor — install refused: `requires R >= 4.3.0`. Confirms the floor bites. (The code itself is fine on 4.2.3; this is the declared minimum doing its job.) |
| 4.3.3 | PASS | **PASS** | Declared floor. NOTEs benign (see below). |
| 4.5.1 | PASS | **PASS** | Current release. NOTEs benign (see below). |

If the below-floor version ever PASSes, the version floor isn't being enforced.

The passing runs are clean — **0 ERRORs, 0 WARNINGs**, PDF manual builds OK.
Every remaining NOTE is either expected or an artifact of the container, not a
package defect:

- *New submission* — expected for a package not yet on CRAN (unavoidable).
- *Compilation used non-portable flags* (`-Wdate-time`,
  `-Werror=format-security`, `-Wformat`) — injected by the container's Debian R
  build, not by this package; absent on CRAN's own machines.
- *HTML version of manual* — `no command 'tidy' found` / `V8 unavailable`:
  the container lacks those optional tools; CRAN has them.
- *Future file timestamps* (intermittent) — the sandboxed container can't
  reach a time server to verify timestamps; environmental.

A real WARNING was found and fixed during this exercise: `arma::syl()` is
deprecated in current Armadillo, replaced with `arma::sylvester()` in
`src/solve_sylvester.cpp`. The package's tests are self-contained
(`tests/testthat/test-basic.R`); an earlier SciPy/reticulate comparison test
used only for development benchmarking was removed.

## Files

- `Dockerfile` — `ARG R_VERSION`, deps, package source, runs `check.sh`.
- `check.sh` — `R CMD build` then full `R CMD check --as-cran` (with PDF
  manual) on the tarball; on failure it dumps `00install.out` and any
  test-failure output so the log is self-explanatory.
- `run-matrix.ps1` / `run-matrix.sh` — loop versions, build + run, summarize.

## Troubleshooting

### Docker won't start: `wsl-keepalive failed to start`

Symptom — Docker Desktop hangs on startup with:

```
creating distribution storage: keeping data distribution alive:
waiting for wsl-keepalive to be ready: wsl-keepalive failed to start
```

Common after a Docker/WSL upgrade leaves an orphaned, corrupt
`docker-desktop-data` WSL distro (older Docker used two distros;
current Docker uses a single `docker-desktop`). `wsl --shutdown` and
`wsl --update` alone do **not** fix corrupt distro data.

Fix (destructive — deletes local Docker images/containers/volumes, which are
disposable here; your own `Ubuntu` distro is untouched):

```powershell
# quit Docker Desktop first
wsl --shutdown
wsl --unregister docker-desktop
wsl --unregister docker-desktop-data   # ignore error if it doesn't exist
wsl --set-default Ubuntu               # stop a stale docker distro being default
# relaunch Docker Desktop; it recreates its distro cleanly (~1 min)
```

### PowerShell runner aborts immediately on `docker build`

`run-matrix.ps1` intentionally sets `$ErrorActionPreference = 'Continue'`, not
`'Stop'`. Docker BuildKit writes progress to **stderr**; under `'Stop'`,
PowerShell turns the first stderr line into a terminating error
(`NativeCommandError`) and aborts before the build starts. The runner drives
off `$LASTEXITCODE` instead. Don't change it back to `'Stop'`.
