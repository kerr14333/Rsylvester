# Deterministic random test matrices (seeded for reproducibility).

rand_real <- function(nr, nc, seed) {
  set.seed(seed)
  matrix(rnorm(nr * nc), nr, nc)
}

rand_cplx <- function(nr, nc, seed) {
  set.seed(seed)
  matrix(rnorm(nr * nc), nr, nc) + 1i * matrix(rnorm(nr * nc), nr, nc)
}
