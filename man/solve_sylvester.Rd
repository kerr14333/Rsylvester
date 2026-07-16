\name{solve_sylvester}
\alias{solve_sylvester}
\alias{sylvester}
\alias{sylvester-package}
\title{Solve a Sylvester matrix equation}
\description{
  Solves the Sylvester matrix equation
  \deqn{A X + X B = Q}
  for the unknown matrix \eqn{X}, mirroring
  \code{scipy.linalg.solve_sylvester}. Real inputs are dispatched to
  Armadillo's LAPACK-backed solver (the same \code{dtrsyl} routine SciPy
  uses); complex inputs use a Bartels--Stewart implementation (Schur
  decomposition plus triangular back-substitution).
}
\usage{
solve_sylvester(a, b, q)
}
\arguments{
  \item{a}{Square matrix (\eqn{n \times n}), real or complex.}
  \item{b}{Square matrix (\eqn{m \times m}), real or complex.}
  \item{q}{Right-hand side matrix (\eqn{n \times m}), real or complex.}
}
\details{
  A unique solution exists if and only if \eqn{A} and \eqn{-B} share no
  eigenvalue. If they do, the underlying triangular system is singular and an
  error is raised (matching SciPy, which raises \code{LinAlgError}).

  If any of \code{a}, \code{b}, \code{q} is complex, all three are promoted to
  complex and the complex solver is used; otherwise the real solver runs.
}
\value{
  The solution matrix \eqn{X} (\eqn{n \times m}). Complex if any input is
  complex, otherwise real.
}
\references{
  Bartels, R. H. and Stewart, G. W. (1972). Solution of the matrix equation
  \eqn{AX + XB = C}. \emph{Communications of the ACM}, 15(9), 820--826.
}
\examples{
set.seed(1)
A <- matrix(rnorm(9), 3, 3)
B <- matrix(rnorm(4), 2, 2)
Q <- matrix(rnorm(6), 3, 2)

X <- solve_sylvester(A, B, Q)
max(abs(A \%*\% X + X \%*\% B - Q))   # ~ 0

## complex
Ac <- A + 1i * matrix(rnorm(9), 3, 3)
Qc <- Q + 1i * matrix(rnorm(6), 3, 2)
Xc <- solve_sylvester(Ac, B, Qc)
max(Mod(Ac \%*\% Xc + Xc \%*\% B - Qc))   # ~ 0
}
\author{cyg}
\keyword{algebra}
\keyword{array}
