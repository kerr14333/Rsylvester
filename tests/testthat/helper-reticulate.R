# Bind reticulate to the user's Python 3.14 and expose scipy.linalg.
# If reticulate/scipy are unavailable, scipy-comparison tests skip while the
# scipy-independent residual tests still run.

get_scipy_linalg <- local({
  cached <- NULL
  tried <- FALSE
  function() {
    if (tried) return(cached)
    tried <<- TRUE
    if (!requireNamespace("reticulate", quietly = TRUE)) return(NULL)

    py <- Sys.getenv("RETICULATE_PYTHON", "")
    if (!nzchar(py)) {
      for (cand in c("C:/Python314/python.exe", "C:/Python314/python")) {
        if (file.exists(cand)) { py <- cand; break }
      }
    }
    ok <- tryCatch({
      if (nzchar(py)) reticulate::use_python(py, required = TRUE)
      reticulate::py_available(initialize = TRUE)
    }, error = function(e) FALSE)
    if (!isTRUE(ok)) return(NULL)

    cached <<- tryCatch(
      reticulate::import("scipy.linalg", delay_load = FALSE),
      error = function(e) NULL
    )
    cached
  }
})

skip_if_no_scipy <- function() {
  if (is.null(get_scipy_linalg())) {
    testthat::skip("scipy / reticulate not available")
  }
}

# Random test matrices with a deterministic seed.
rand_real <- function(nr, nc, seed) {
  set.seed(seed)
  matrix(rnorm(nr * nc), nr, nc)
}

rand_cplx <- function(nr, nc, seed) {
  set.seed(seed)
  matrix(rnorm(nr * nc), nr, nc) + 1i * matrix(rnorm(nr * nc), nr, nc)
}

# Relative-scaled max abs difference.
rel_maxdiff <- function(x, y) {
  denom <- max(1, max(Mod(y)))
  max(Mod(x - y)) / denom
}
