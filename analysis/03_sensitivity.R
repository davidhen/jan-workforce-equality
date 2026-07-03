# ------------------------------------------------------------------------------
# 03_sensitivity.R
# Sensitivity of the non-White representation gradient to informative
# non-disclosure ("Prefer not to say", PNTS).
#
#   (1) Extreme bound: all PNTS staff assumed non-White (reassign_frac = 1).
#   (2) Tipping point: fraction of PNTS that would need to be non-White for each
#       senior band to reach parity (RQ >= 1).
#
# Rationale: PNTS is a substantive response category, not item-missingness, and
# rises with band seniority. If non-White staff disproportionately decline to
# disclose, observed senior-band underrepresentation may be overstated. This
# quantifies how much non-disclosure it would take to change the conclusion.
# ------------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)

source(here::here("R", "functions.R"))

sip <- read_csv(here::here("data", "staff_in_post.csv"),
                show_col_types = FALSE)

years <- unique(sip$year)

# ---- (1) Observed vs extreme bound --------------------------------------------
bound_one <- function(frac) {
  sip |>
    group_split(year) |>
    lapply(rq_year, reassign_frac = frac) |>
    bind_rows() |>
    mutate(scenario = if (frac == 0) "observed" else "all_pnts_non_white") |>
    select(scenario, year, band, rq_non_white)
}

sensitivity <- bind_rows(bound_one(0), bound_one(1)) |>
  pivot_wider(names_from = scenario, values_from = rq_non_white) |>
  arrange(year, band)

cat("\n== Observed vs extreme bound (all PNTS -> non-White) ==\n")
print(as.data.frame(sensitivity), digits = 2)

# ---- (2) Tipping point per senior band ----------------------------------------
tip_grid <- expand.grid(yr = years, band = c(6, 7), stringsAsFactors = FALSE)

tip <- tip_grid |>
  rowwise() |>
  mutate(
    frac_to_parity = tipping_point(
      df_year     = sip[sip$year == yr, ],   # raw year frame for this row
      target_band = band
    ),
    pct_to_parity = ifelse(is.na(frac_to_parity), NA_real_, 100 * frac_to_parity)
  ) |>
  ungroup() |>
  rename(year = yr) |>
  arrange(band, year)

cat("\n== Tipping point: % of PNTS that must be non-White for RQ >= 1 ==\n")
cat("   (NA = parity not reachable even if all PNTS were non-White)\n")
print(as.data.frame(tip), digits = 3)

write_csv(sensitivity, here::here("outputs", "sensitivity_rq_bound.csv"))
write_csv(tip,         here::here("outputs", "sensitivity_tipping_point.csv"))
