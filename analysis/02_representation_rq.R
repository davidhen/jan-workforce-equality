# ------------------------------------------------------------------------------
# 02_representation_rq.R
# Reproduces Table 2: non-White representation quotients (RQs) across pay bands,
# by year (observed / complete-case).
# ------------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)

source(here::here("R", "functions.R"))

sip <- read_csv(here::here("data", "staff_in_post.csv"),
                show_col_types = FALSE)

# Apply rq_year() within each financial year (observed => reassign_frac = 0)
rq_observed <- sip |>
  group_split(year) |>
  lapply(rq_year, reassign_frac = 0) |>
  bind_rows() |>
  arrange(year, band)

rq_table <- rq_observed |>
  select(year, band, rq_non_white) |>
  pivot_wider(names_from = band, values_from = rq_non_white,
              names_prefix = "Band ")

print(rq_table)

write_csv(rq_observed |> select(year, band, rq_non_white),
          here::here("outputs", "table2_representation_rq.csv"))
