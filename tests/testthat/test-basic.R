# scipy-independent checks: residual ||A X + X B - Q|| and known cases.

residual <- function(A, B, Q, X) max(Mod(A %*% X + X %*% B - Q))

test_that("1x1 scalar case matches closed form", {
  # a*x + x*b = q  ->  x = q / (a + b)
  a <- matrix(2); b <- matrix(3); q <- matrix(10)
  x <- solve_sylvester(a, b, q)
  expect_equal(as.numeric(x), 10 / 5)
})

test_that("real residual is ~0 across shapes", {
  dims <- list(c(1, 1), c(2, 2), c(3, 3), c(5, 5),
               c(2, 3), c(3, 2), c(5, 8), c(8, 5),
               c(1, 4), c(4, 1), c(10, 10), c(13, 7), c(7, 13))
  for (d in dims) {
    n <- d[1]; m <- d[2]
    A <- rand_real(n, n, 100 + n)
    B <- rand_real(m, m, 200 + m)
    Q <- rand_real(n, m, 300 + n * 31 + m)
    X <- solve_sylvester(A, B, Q)
    expect_equal(dim(X), c(n, m))
    expect_lt(residual(A, B, Q, X), 1e-8,
              label = sprintf("real residual %dx%d", n, m))
  }
})

test_that("complex residual is ~0 across shapes", {
  dims <- list(c(1, 1), c(2, 2), c(3, 3), c(5, 5),
               c(2, 3), c(3, 2), c(5, 8), c(8, 5), c(10, 10), c(7, 13))
  for (d in dims) {
    n <- d[1]; m <- d[2]
    A <- rand_cplx(n, n, 400 + n)
    B <- rand_cplx(m, m, 500 + m)
    Q <- rand_cplx(n, m, 600 + n * 31 + m)
    X <- solve_sylvester(A, B, Q)
    expect_true(is.complex(X))
    expect_equal(dim(X), c(n, m))
    expect_lt(residual(A, B, Q, X), 1e-8,
              label = sprintf("complex residual %dx%d", n, m))
  }
})

test_that("input validation errors", {
  expect_error(solve_sylvester(matrix(1:6, 2, 3), diag(2), matrix(0, 2, 2)),
               "square")
  expect_error(solve_sylvester(diag(2), diag(3), matrix(0, 3, 3)),
               "must be")  # q shape mismatch
})
