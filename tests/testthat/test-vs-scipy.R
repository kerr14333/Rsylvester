# Core comparison: R output must match scipy.linalg.solve_sylvester across a
# range of dimensions, real and complex.

dims <- list(c(1, 1), c(2, 2), c(3, 3), c(4, 4), c(5, 5),
             c(2, 3), c(3, 2), c(5, 8), c(8, 5),
             c(1, 4), c(4, 1), c(10, 10), c(13, 7), c(7, 13))

test_that("real: R matches scipy across dimensions", {
  skip_if_no_scipy()
  scipy <- get_scipy_linalg()
  for (d in dims) {
    n <- d[1]; m <- d[2]
    A <- rand_real(n, n, 1000 + n)
    B <- rand_real(m, m, 2000 + m)
    Q <- rand_real(n, m, 3000 + n * 37 + m)

    x_r  <- solve_sylvester(A, B, Q)
    x_py <- scipy$solve_sylvester(A, B, Q)

    expect_lt(rel_maxdiff(x_r, x_py), 1e-9,
              label = sprintf("real %dx%d vs scipy", n, m))
  }
})

test_that("complex: R matches scipy across dimensions", {
  skip_if_no_scipy()
  scipy <- get_scipy_linalg()
  for (d in dims) {
    n <- d[1]; m <- d[2]
    A <- rand_cplx(n, n, 4000 + n)
    B <- rand_cplx(m, m, 5000 + m)
    Q <- rand_cplx(n, m, 6000 + n * 37 + m)

    x_r  <- solve_sylvester(A, B, Q)
    x_py <- scipy$solve_sylvester(A, B, Q)

    expect_lt(rel_maxdiff(x_r, x_py), 1e-9,
              label = sprintf("complex %dx%d vs scipy", n, m))
  }
})

test_that("mixed real/complex inputs match scipy", {
  skip_if_no_scipy()
  scipy <- get_scipy_linalg()
  n <- 4; m <- 6
  A <- rand_cplx(n, n, 7001)
  B <- rand_real(m, m, 7002)          # real B
  Q <- rand_cplx(n, m, 7003)

  x_r  <- solve_sylvester(A, B, Q)
  x_py <- scipy$solve_sylvester(A, B + 0i, Q)  # scipy needs consistent complex
  expect_lt(rel_maxdiff(x_r, x_py), 1e-9)
})
