# Cross-version check image for the sylvester package.
# Base = pinned rocker/r-ver (exact R patch release). RSPM in these images
# serves Linux binary packages, so the R-package installs are fast; only the
# sylvester package itself compiles from source.
ARG R_VERSION=4.4.1
FROM rocker/r-ver:${R_VERSION}

# System deps:
#  - build-essential/gfortran: RcppArmadillo compiles against R's BLAS/LAPACK.
#  - texinfo + texlive-*: build the PDF reference manual so `R CMD check
#    --as-cran` exercises it exactly as CRAN does (texlive-fonts-extra supplies
#    the 'inconsolata' font the R manual class needs).
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gfortran \
        texinfo \
        texlive-latex-base texlive-latex-recommended \
        texlive-fonts-recommended texlive-fonts-extra \
    && rm -rf /var/lib/apt/lists/*

# R build/check deps.
RUN R -q -e "install.packages(c('Rcpp','RcppArmadillo','testthat'))" \
    && R -q -e "stopifnot(all(c('Rcpp','RcppArmadillo','testthat') %in% rownames(installed.packages())))"

WORKDIR /work
COPY . /pkg
COPY docker/check.sh /usr/local/bin/check.sh
RUN chmod +x /usr/local/bin/check.sh

# Run the CRAN check by default; exit code propagates to `docker run`.
CMD ["/usr/local/bin/check.sh"]
