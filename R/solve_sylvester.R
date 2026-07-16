#' Solve a Sylvester matrix equation
#'
#' Solves \eqn{A X + X B = Q} for \eqn{X}, mirroring
#' \code{scipy.linalg.solve_sylvester}. Real inputs use Armadillo's
#' LAPACK-backed solver; complex inputs use a Bartels-Stewart implementation.
#'
#' @param a Square matrix (n x n), real or complex.
#' @param b Square matrix (m x m), real or complex.
#' @param q Right-hand side (n x m), real or complex.
#' @return The solution matrix \eqn{X} (n x m). Complex if any input is complex.
#' @export
solve_sylvester <- function(a, b, q) {
  a <- as.matrix(a)
  b <- as.matrix(b)
  q <- as.matrix(q)

  if (nrow(a) != ncol(a)) stop("`a` must be square.")
  if (nrow(b) != ncol(b)) stop("`b` must be square.")
  if (nrow(q) != nrow(a) || ncol(q) != ncol(b)) {
    stop(sprintf("`q` must be %d x %d (nrow(a) x ncol(b)), got %d x %d.",
                 nrow(a), ncol(b), nrow(q), ncol(q)))
  }

  if (is.complex(a) || is.complex(b) || is.complex(q)) {
    solve_sylvester_cplx(a + 0i, b + 0i, q + 0i)
  } else {
    solve_sylvester_real(a, b, q)
  }
}
