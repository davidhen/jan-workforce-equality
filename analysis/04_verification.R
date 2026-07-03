# ------------------------------------------------------------------------------
# 04_verification.R
# Confirms the R implementation reproduces the published (Excel) estimates.
# Compares R-computed RRs / CIs (Table 4) and RQs (Table 2) against the values
# reported in the manuscript, and reports the maximum absolute discrepancy.
# ------------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)

source(here::here("R", "functions.R"))

# ---- Published values (as printed in the manuscript tables) -------------------
published_rr <- tibble::tribble(
  ~band, ~year,     ~rr,  ~ci_low, ~ci_high,
  5, "2021/22",    1.15,  1.05,    1.27,
  5, "2022/23",    1.37,  1.26,    1.49,
  5, "2023/24",    1.27,  1.13,    1.44,
  6, "2021/22",    1.29,  1.04,    1.60,
  6, "2022/23",    2.02,  1.51,    2.69,
  6, "2023/24",    1.96,  1.41,    2.72,
  7, "2021/22",    2.10,  1.17,    3.77,
  7, "2022/23",    2.10,  1.17,    3.76,
  7, "2023/24",    2.09,  1.16,    3.76
)

published_rq <- tibble::tribble(
  ~year,     ~band, ~rq,
  "2021/22", 5, 1.49, "2021/22", 6, 0.50, "2021/22", 7, 0.27,
  "2022/23", 5, 1.51, "2022/23", 6, 0.56, "2022/23", 7, 0.31,
  "2023/24", 5, 1.52, "2023/24", 6, 0.56, "2023/24", 7, 0.28,
  "2024/25", 5, 1.56, "2024/25", 6, 0.48, "2024/25", 7, 0.22
)

# ---- Recompute in R -----------------------------------------------------------
rr_r <- read_csv(here::here("data", "recruitment.csv"), show_col_types = FALSE) |>
  pivot_wider(names_from = ethnicity, values_from = c(interviews, offers)) |>
  rowwise() |>
  mutate(res = list(rr_offer(offers_white, interviews_white,
                             offers_non_white, interviews_non_white))) |>
  tidyr::unnest(res) |>
  ungroup() |>
  select(band, year, rr, ci_low, ci_high)

rq_r <- read_csv(here::here("data", "staff_in_post.csv"), show_col_types = FALSE) |>
  group_split(year) |>
  lapply(rq_year, reassign_frac = 0) |>
  bind_rows() |>
  select(year, band, rq = rq_non_white)

# ---- Compare (rounded to the manuscript's reported precision) -----------------
rr_check <- published_rr |>
  left_join(rr_r, by = c("band", "year"), suffix = c("_pub", "_r")) |>
  mutate(
    d_rr = abs(round(rr_r, 2) - rr_pub),
    d_lo = abs(round(ci_low_r, 2) - ci_low_pub),
    d_hi = abs(round(ci_high_r, 2) - ci_high_pub)
  )

rq_check <- published_rq |>
  left_join(rq_r, by = c("year", "band"), suffix = c("_pub", "_r")) |>
  mutate(d_rq = abs(round(rq_r, 2) - rq_pub))

cat("Max |R - published| after rounding to reported precision:\n")
cat(sprintf("  RR       : %.3f\n", max(rr_check$d_rr)))
cat(sprintf("  RR CI low: %.3f\n", max(rr_check$d_lo)))
cat(sprintf("  RR CI hi : %.3f\n", max(rr_check$d_hi)))
cat(sprintf("  RQ       : %.3f\n", max(rq_check$d_rq)))

stopifnot(
  max(rr_check$d_rr) <= 0.01,
  max(rr_check$d_lo) <= 0.01,
  max(rr_check$d_hi) <= 0.01,
  max(rq_check$d_rq) <= 0.01
)
cat("\nAll estimates reproduce the published values to the reported precision.\n")
