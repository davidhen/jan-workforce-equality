# ------------------------------------------------------------------------------
# 01_recruitment_rr.R
# Reproduces Table 4: relative risk of a conditional offer after interview
# (White vs non-White), with 95% CIs and p-values, by band and year.
# ------------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)
library(purrr)

source(here::here("R", "functions.R"))

recruitment <- read_csv(here::here("data", "recruitment.csv"),
                        show_col_types = FALSE)

# One row per band-year with White and non-White columns side by side
wide <- recruitment |>
  pivot_wider(names_from = ethnicity,
              values_from = c(interviews, offers))

rr_table <- wide |>
  mutate(res = pmap(
    list(offers_white, interviews_white, offers_non_white, interviews_non_white),
    rr_offer
  )) |>
  select(band, year, res) |>
  unnest(res) |>
  arrange(band, year)

rr_display <- rr_table |>
  transmute(
    band, year,
    `Offer rate (White)`     = sprintf("%.0f%%", 100 * rate_white),
    `Offer rate (non-White)` = sprintf("%.0f%%", 100 * rate_non_white),
    `RR (95% CI)` = sprintf("%.2f (%.2f-%.2f)", rr, ci_low, ci_high),
    p = ifelse(p_value < 0.001, "<0.001", sprintf("%.3f", p_value))
  )

print(rr_display, n = Inf)

write_csv(rr_table, here::here("outputs", "table4_recruitment_rr.csv"))
