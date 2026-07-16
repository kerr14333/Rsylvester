// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>

// Solve the Sylvester equation  A X + X B = Q.
//
// scipy.linalg.solve_sylvester solves the same equation via the
// Bartels-Stewart algorithm (Schur decomposition + LAPACK *trsyl).
//
// Real case: Armadillo's syl(A, B, C) solves  A X + X B + C = 0, i.e.
// A X + X B = -C, and is backed by the very LAPACK dtrsyl routine scipy uses,
// so results agree to machine precision. Pass C = -Q.

// [[Rcpp::export]]
arma::mat solve_sylvester_real(const arma::mat& A,
                               const arma::mat& B,
                               const arma::mat& Q) {
  return arma::syl(A, B, -Q);
}

// Complex case: Armadillo's syl is real-only, so implement Bartels-Stewart
// directly.
//   1. schur:  A = U R U^H,  R upper-triangular
//   2. schur:  B = V S V^H,  S upper-triangular
//   3. F = U^H Q V
//   4. Solve R Y + Y S = F column by column. For column k (S upper-tri):
//        (R + S(k,k) I) y_k = F(:,k) - sum_{j<k} S(j,k) y_j
//      with R + S(k,k) I upper-triangular -> back-substitution.
//   5. X = U Y V^H

// [[Rcpp::export]]
arma::cx_mat solve_sylvester_cplx(const arma::cx_mat& A,
                                  const arma::cx_mat& B,
                                  const arma::cx_mat& Q) {
  arma::cx_mat U, R, V, S;

  if (!arma::schur(U, R, A)) {
    Rcpp::stop("Schur decomposition of A failed.");
  }
  if (!arma::schur(V, S, B)) {
    Rcpp::stop("Schur decomposition of B failed.");
  }

  const arma::uword n = R.n_rows;
  const arma::uword m = S.n_rows;

  arma::cx_mat F = U.t() * Q * V;          // .t() = conjugate transpose
  arma::cx_mat Y(n, m, arma::fill::zeros);
  arma::cx_mat I = arma::eye<arma::cx_mat>(n, n);

  for (arma::uword k = 0; k < m; ++k) {
    arma::cx_vec rhs = F.col(k);
    for (arma::uword j = 0; j < k; ++j) {
      rhs -= S(j, k) * Y.col(j);
    }
    arma::cx_mat M = R + S(k, k) * I;      // upper-triangular
    arma::cx_vec yk;
    if (!arma::solve(yk, arma::trimatu(M), rhs)) {
      Rcpp::stop("Singular triangular system: A and -B share an eigenvalue "
                 "(solution is not unique).");
    }
    Y.col(k) = yk;
  }

  return U * Y * V.t();
}
