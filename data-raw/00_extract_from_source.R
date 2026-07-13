# ------------------------------------------------------------------------------
# data-raw/00_extract_from_source.R
#
# Extracts the tidy analytic inputs (data/recruitment.csv, data/staff_in_post.csv)
# from the source workbook ED_Data_20212025.xlsx.
#
# Why the workbook needs hand-holding (all handled below):
#   * Each sheet stacks FOUR financial-year blocks vertically, with the year in
#     a free-text title cell above each block rather than in a column.
#   * "Grand Total" rows are interleaved with the band rows.
#   * Representation quotients are pre-computed in columns O/P (we ignore these
#     and recompute downstream so the calculation is auditable).
#   * The recruitment "Interviews" block carries stray secondary counts in
#     columns O/P for some bands; these are not part of the analysis and are
#     not read.
#   * Column headers repeat in every block and are not used for parsing; we key
#     entirely off fixed cell anchors, which is more robust than name-matching
#     against a sheet whose headers appear four times.
# ------------------------------------------------------------------------------

library(readxl)
library(dplyr)
library(purrr)
library(readr)
library(here)

src <- here("data-raw", "ED Data 2021-2025.xlsx")

# ---- Recruitment -------------------------------------------------------------
# Sheet "Recruitment": four stacked blocks. For each block, Bands 5/6/7 sit on
# three consecutive rows. Interview counts are in cols M (BME) / N (White);
# conditional-offer counts in cols R (BME) / S (White). 2024/25 is excluded from
# the analysis (applicant-tracking data-quality error) and is not extracted.
#
# `band5_row` = worksheet row of the Band 5 line in each block.
rec_blocks <- tribble(
  ~year,      ~band5_row,
  "2021/22",  55,
  "2022/23",  41,
  "2023/24",  26
)

read_rec_block <- function(year, band5_row) {
  interviews <- read_excel(
    src, sheet = "Recruitment", col_names = c("nw", "white"),
    range = sprintf("M%d:N%d", band5_row, band5_row + 2)
  )
  offers <- read_excel(
    src, sheet = "Recruitment", col_names = c("nw", "white"),
    range = sprintf("R%d:S%d", band5_row, band5_row + 2)
  )
  tibble(
    band       = c(5, 6, 7),
    year       = year,
    int_nw     = interviews$nw,  int_white    = interviews$white,
    off_nw     = offers$nw,      off_white     = offers$white
  )
}

recruitment <- pmap_dfr(rec_blocks, read_rec_block) |>
  # reshape to one row per band-year-ethnicity
  tidyr::pivot_longer(
    cols = c(int_nw, int_white, off_nw, off_white),
    names_to = c(".value", "ethnicity"),
    names_pattern = "(int|off)_(nw|white)"
  ) |>
  transmute(
    band,
    year,
    ethnicity  = if_else(ethnicity == "nw", "non_white", "white"),
    interviews = int,
    offers     = off
  ) |>
  arrange(band, year, desc(ethnicity))

# ---- Staff in post -----------------------------------------------------------
# Sheet "Ethnic distr + RQs": four stacked blocks. Bands 5/6/7 on three
# consecutive rows; cols C (White) / D (BME) / E (PNTS). "Unknown" (col L) is
# item-missing ethnicity, handled by complete-case and not needed here.
sip_blocks <- tribble(
  ~year,      ~band5_row,
  "2021/22",  32,
  "2022/23",  23,
  "2023/24",  14,
  "2024/25",  5
)

read_sip_block <- function(year, band5_row) {
  x <- read_excel(
    src, sheet = "Ethnic distr + RQs",
    col_names = c("white", "non_white", "pnts"),
    range = sprintf("C%d:E%d", band5_row, band5_row + 2)
  )
  tibble(year = year, band = c(5, 6, 7),
         white = x$white, non_white = x$non_white, pnts = x$pnts)
}

staff_in_post <- pmap_dfr(sip_blocks, read_sip_block) |>
  arrange(year, band)

# ---- Validation --------------------------------------------------------------
# Cheap integrity checks: expected shape, no missing counts, integer-valued.
stopifnot(
  nrow(recruitment)   == 18,               # 3 bands x 3 years x 2 groups
  nrow(staff_in_post) == 12,               # 3 bands x 4 years
  !anyNA(recruitment), !anyNA(staff_in_post),
  all(recruitment$offers <= recruitment$interviews)
)

# ---- Write -------------------------------------------------------------------
write_csv(recruitment,   here("data", "recruitment.csv"))
write_csv(staff_in_post, here("data", "staff_in_post.csv"))

message("Extracted ", nrow(recruitment), " recruitment rows and ",
        nrow(staff_in_post), " staff-in-post rows to data/.")
