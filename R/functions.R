# ------------------------------------------------------------------------------
# functions.R
# Core analytic functions for the workforce equality monitoring analysis.
# All estimators are deliberately simple and auditable; they reproduce the
# published Excel calculations exactly (see analysis/04_verification.R).
# ------------------------------------------------------------------------------

# Relative risk of a conditional offer (White vs non-White) from a 2x2 count set,
# with a 95% CI on the log scale (Katz method) and a Pearson chi-square p-value
# (no continuity correction, matching the published analysis).
#
# Arguments are counts within a single band-year:
#   off_w, int_w  : conditional offers and interviews, White
#   off_nw, int_nw: conditional offers and interviews, non-White
# Returns a one-row data frame.
rr_offer <- function(off_w, int_w, off_nw, int_nw, conf = 0.95) {
  p_w  <- off_w  / int_w
  p_nw <- off_nw / int_nw
  rr   <- p_w / p_nw

  # Katz standard error of log(RR)
  se_log <- sqrt(1 / off_w - 1 / int_w + 1 / off_nw - 1 / int_nw)
  z      <- stats::qnorm(1 - (1 - conf) / 2)
  lcl    <- exp(log(rr) - z * se_log)
  ucl    <- exp(log(rr) + z * se_log)

  # Pearson chi-square on offer vs no-offer x ethnicity (no Yates correction)
  tab <- matrix(c(off_w,  int_w  - off_w,
                  off_nw, int_nw - off_nw),
                nrow = 2, byrow = TRUE)
  p   <- suppressWarnings(stats::chisq.test(tab, correct = FALSE)$p.value)

  data.frame(
    rate_white     = p_w,
    rate_non_white = p_nw,
    rr             = rr,
    ci_low         = lcl,
    ci_high        = ucl,
    p_value        = p
  )
}

# Representation quotient for a subgroup within a band.
#
#   band_count    : subgroup count in the band
#   band_total    : total headcount in the band
#   overall_count : subgroup count across the whole (analysed) workforce
#   overall_total : total headcount across the whole (analysed) workforce
#
# RQ = (band_count / band_total) / (overall_count / overall_total).
# RQ = 1 equal representation; > 1 over-; < 1 under-representation.
rq <- function(band_count, band_total, overall_count, overall_total) {
  (band_count / band_total) / (overall_count / overall_total)
}

# Compute non-White RQs for every band within one year from a tidy staff-in-post
# data frame (columns: band, white, non_white, pnts). `reassign_frac` is the
# fraction of "Prefer not to say" staff assumed to be non-White, applied
# uniformly across bands (0 = observed; 1 = extreme adversarial bound).
# The band denominator is always the full headcount (white + non_white + pnts);
# reassignment moves PNTS into the non-White numerator, not out of the total.
rq_year <- function(df_year, reassign_frac = 0) {
  stopifnot(all(c("band", "white", "non_white", "pnts") %in% names(df_year)))
  df_year$band_total    <- df_year$white + df_year$non_white + df_year$pnts
  df_year$nw_effective  <- df_year$non_white + reassign_frac * df_year$pnts

  overall_nw    <- sum(df_year$nw_effective)
  overall_total <- sum(df_year$band_total)

  df_year$rq_non_white <- rq(df_year$nw_effective, df_year$band_total,
                             overall_nw, overall_total)
  df_year$overall_share_non_white <- overall_nw / overall_total
  df_year
}

# Tipping point: the minimum fraction of "Prefer not to say" staff (assumed
# uniform across bands) that would need to be non-White for a target band's
# non-White RQ to reach parity (>= 1) in a given year. Returns NA if parity is
# not reachable even when all PNTS are reassigned (i.e. underrepresentation is
# robust to the most extreme assumption). Solved by bisection.
tipping_point <- function(df_year, target_band, tol = 1e-6) {
  rq_at <- function(f) {
    out <- rq_year(df_year, reassign_frac = f)
    out$rq_non_white[out$band == target_band]
  }
  if (rq_at(1) < 1) return(NA_real_)   # never reaches parity
  lo <- 0; hi <- 1
  while (hi - lo > tol) {
    mid <- (lo + hi) / 2
    if (rq_at(mid) >= 1) hi <- mid else lo <- mid
  }
  hi
}
