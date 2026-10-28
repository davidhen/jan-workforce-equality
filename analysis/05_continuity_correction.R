# ------------------------------------------------------------------------------
# 05_continuity_correction.R
# Sensitivity of the Table 4 p-values to Yates' continuity correction
# (Reviewer 1, second resubmission).
#
# The primary analysis uses Pearson chi-square WITHOUT continuity correction.
# This script (1) reports the smallest expected cell count in each 2x2 table,
# (2) recomputes p with and without Yates' correction, and (3) asserts that the
# correction changes no inference at alpha = 0.05. The RRs and Katz CIs are
# unaffected by the choice of test and are not recomputed here.
# ------------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)

source(here::here("R", "functions.R"))

alpha <- 0.05

chisq_both <- function(off_w, int_w, off_nw, int_nw) {
  tab <- matrix(c(off_w,  int_w  - off_w,
                  off_nw, int_nw - off_nw),
                nrow = 2, byrow = TRUE)
  uncorr <- suppressWarnings(stats::chisq.test(tab, correct = FALSE))
  yates  <- suppressWarnings(stats::chisq.test(tab, correct = TRUE))
  tibble::tibble(
    min_expected = min(uncorr$expected),
    p_uncorrected = uncorr$p.value,
    p_yates       = yates$p.value
  )
}

cc <- read_csv(here::here("data", "recruitment.csv"), show_col_types = FALSE) |>
  pivot_wider(names_from = ethnicity, values_from = c(interviews, offers)) |>
  rowwise() |>
  mutate(res = list(chisq_both(offers_white, interviews_white,
                               offers_non_white, interviews_non_white))) |>
  unnest(res) |>
  ungroup() |>
  mutate(
    p_ratio            = p_yates / p_uncorrected,
    same_inference     = (p_uncorrected < alpha) == (p_yates < alpha)
  ) |>
  select(band, year, min_expected, p_uncorrected, p_yates, p_ratio,
         same_inference) |>
  arrange(band, year)

cat("\n== Table 4 p-values with and without Yates' continuity correction ==\n")
print(as.data.frame(cc), digits = 3)

cat(sprintf("\nSmallest expected cell count across all tables: %.1f\n",
            min(cc$min_expected)))
cat(sprintf("Largest Yates-corrected p: %.4f\n", max(cc$p_yates)))

# Published (uncorrected) p for the only non-<0.001 Band 5/6 cell, as printed.
stopifnot(
  abs(round(cc$p_uncorrected[cc$band == 6 & cc$year == "2021/22"], 3) - 0.013) < 1e-9,
  all(cc$same_inference)
)
cat("Continuity correction changes no inference at alpha = 0.05.\n")

write_csv(cc, here::here("outputs", "sensitivity_continuity_correction.csv"))
