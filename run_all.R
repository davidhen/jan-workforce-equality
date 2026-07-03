# Run the full analysis. From the project root:  Rscript run_all.R
# (or open the .Rproj and source this file)

source(here::here("analysis", "01_recruitment_rr.R"))
source(here::here("analysis", "02_representation_rq.R"))
source(here::here("analysis", "03_sensitivity.R"))
source(here::here("analysis", "04_verification.R"))

cat("\nDone. Outputs written to ./outputs/\n")
