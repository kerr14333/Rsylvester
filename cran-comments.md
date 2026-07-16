## Test environments

- Local cross-version check via Docker (`rocker/r-ver`), full
  `R CMD check --as-cran` including the PDF manual:
  - R 4.3.3 (Ubuntu) — the declared minimum (`Depends: R (>= 4.3.0)`)
  - R 4.5.1 (Ubuntu) — current release
  - also passed on R 4.2.3; installs and passes tests on R 4.0.5
- Pre-submission platform coverage still to run: win-builder (release +
  r-devel), mac-builder, R-hub.

## R CMD check results

0 ERRORs, 0 WARNINGs on R 4.4.1 and R 4.5.1.

NOTEs:

- New submission — this is the first submission of this package.

(In the local Docker containers an additional NOTE about "non-portable
compilation flags" appears; those flags come from the container's Debian R
build, not from the package, and do not appear on standard CRAN machines.)

## Downstream dependencies

None (new package).
