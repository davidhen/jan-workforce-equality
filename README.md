# Routine data for workforce equality monitoring — analysis code

Reproducible R code for the recruitment and representation analyses in
*"Routine Data for Workforce Equality Monitoring: Ethnic Inequalities in
Recruitment and Workforce Representation in Nursing and Midwifery"* (JAN,
manuscript 8320876).

The code reproduces every estimate in the manuscript — relative risks (Table 4),
representation quotients (Table 2), and the sensitivity analyses — and
independently verifies the original calculations, which were performed in
Microsoft Excel.

## Reproducibility and data

The inputs under `data/` are the **aggregate counts already published in the
manuscript** (Table 1 staff-in-post; Table 3 recruitment). Because every
estimate derives solely from these published aggregates, the code is fully
runnable from this repository alone. 

## Structure

```
.
├── data-raw/                 extraction pipeline (raw file)
│   └── 00_extract_from_source.R
├── data/                     aggregate counts
│   ├── recruitment.csv
│   └── staff_in_post.csv
├── R/
│   └── functions.R           rr_offer(), rq(), rq_year(), tipping_point()
├── analysis/
│   ├── 01_recruitment_rr.R   Table 4: relative risks + 95% CIs + p
│   ├── 02_representation_rq.R Table 2: representation quotients
│   ├── 03_sensitivity.R      non-disclosure bound + tipping point
│   ├── 04_verification.R     confirms R reproduces the published values
│   └── 05_continuity_correction.R  p-values with vs without Yates' correction
├── outputs/                  generated tables (created on run)
└── run_all.R
```

## Running

```r
# from the project root
source("run_all.R")          # or: Rscript run_all.R
```

Dependencies: `dplyr`, `tidyr`, `readr`, `purrr`, `tibble`, `here`
`readxl`. Developed under R 4.5.0

## Regenerating the data from source

`data/` is generated from the source workbook by `data-raw/00_extract_from_source.R`.
It should reproduce the committed CSVs exactly — any diff signals an upstream change. 
The script keys off fixed cell anchors (the sheet stacks four year-blocks with the year in title
cells, interleaves "Grand Total" rows, and carries pre-computed RQs and stray
secondary counts we deliberately ignore), so it is intentionally explicit rather
than header-driven.

## Methods notes

- **Relative risk** of a conditional offer after interview (White vs non-White),
  with 95% CIs on the log scale (Katz method) and a Pearson chi-square p-value
  without continuity correction. RR > 1 indicates a higher offer rate for White
  candidates.
- **Representation quotient (RQ)** = (subgroup share within band) ÷ (subgroup
  share in the analysed workforce, Bands 5–7). RQ = 1 is equal representation.
- **Sensitivity to non-disclosure.** "Prefer not to say" (PNTS) is a substantive
  response category, not item-missingness, and its prevalence rises with band
  seniority. `03_sensitivity.R` recomputes RQs under the extreme assumption that
  all PNTS staff are non-White, and reports the tipping point — the fraction of
  PNTS that would need to be non-White for a senior band to reach parity.

## Continuity correction

`05_continuity_correction.R` addresses Reviewer 1's query on Yates' correction.
The Table 4 p-values use Pearson chi-square without continuity correction. The
smallest expected cell count in any 2x2 table is 18.0 (Band 7), so the
small-sample concern behind Yates' correction does not arise. Applying the
correction raises p-values modestly (largest: 0.016, Band 6 2021/22) and changes
no inference at alpha = 0.05; the script asserts this. RRs and Katz CIs do not
depend on the choice of test.

## Verified results

`04_verification.R` reproduces all published RRs, CIs and RQs to the reported
precision (max absolute discrepancy ≤ 0.01).

Sensitivity of the non-White representation gradient (RQ), observed vs the
extreme bound (all PNTS assumed non-White):

| Year    | Band 5 obs → bound | Band 6 obs → bound | Band 7 obs → bound |
|---------|--------------------|--------------------|--------------------|
| 2021/22 | 1.49 → 0.98        | 0.50 → 0.96        | 0.27 → 1.12        |
| 2022/23 | 1.51 → 0.99        | 0.56 → 0.95        | 0.31 → 1.10        |
| 2023/24 | 1.52 → 1.05        | 0.56 → 0.91        | 0.28 → 1.02        |
| 2024/25 | 1.56 → 1.11        | 0.48 → 0.84        | 0.22 → 0.95        |

Tipping point (fraction of PNTS that would need to be non-White for parity):

| Band | 2021/22 | 2022/23 | 2023/24 | 2024/25 |
|------|---------|---------|---------|---------|
| 6    | not reachable | not reachable | not reachable | not reachable |
| 7    | 61%     | 65%     | 93%     | not reachable |

"Not reachable" means the band remains below parity even if **all** non-disclosing
staff were non-White. Band 6 underrepresentation is robust to this assumption in
every year; the Band 7 gap could be closed only under implausibly strong
differential non-disclosure (a majority of all non-disclosers being non-White,
against a disclosed non-White share of ~9–14%). The recruitment findings use
self-reported ethnicity with 0.6% missingness and no PNTS category, and are not
subject to this limitation.
