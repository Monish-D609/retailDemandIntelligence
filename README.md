# Retail Demand Intelligence

**Hierarchical demand forecasting and repeat-purchase prediction for a real e-commerce marketplace, built end to end in R.**

![R](https://img.shields.io/badge/R-4.4%2B-276DC3?logo=r&logoColor=white)
![Shiny](https://img.shields.io/badge/Shiny-golem-blue)
![Pipeline](https://img.shields.io/badge/pipeline-targets-green)
![Reproducible](https://img.shields.io/badge/reproducible-renv-orange)

---

## Table of contents

1. [Overview](#overview)
2. [Key results](#key-results)
3. [Features](#features)
4. [Dataset](#dataset)
5. [Dashboard preview](#dashboard-preview)
6. [Getting started](#getting-started)
7. [Project structure](#project-structure)
8. [Pipeline targets](#pipeline-targets)
9. [Tech stack](#tech-stack)
10. [Validation and data-quality findings](#validation-and-data-quality-findings)
11. [Troubleshooting](#troubleshooting)
12. [Limitations](#limitations)
13. [Roadmap](#roadmap)
14. [Acknowledgments](#acknowledgments)
15. [Author and license](#author-and-license)

---

## Overview

Most retail dashboards describe what already happened. This project answers the two questions a marketplace actually has to act on:

1. **How much will we sell next week, at the category level and in total, and how far can that number be trusted?**
2. **Which first-time customers are worth spending retention budget on, when about 97% of customers never buy a second time?**

It does this on the Olist Brazilian E-Commerce dataset: nine relational tables of real marketplace data with real quirks. Two models are built and validated against baselines on held-out data, and an interactive Shiny dashboard replays the held-out weeks as if they were arriving live.

The full workflow (ingest, transform, model, evaluate, simulate, export, visualize) is a single reproducible `{targets}` pipeline inside an R package structure, with package versions locked by `renv`.

---

## Key results

### Forecasting: hierarchical ETS with MinT reconciliation

Aggregate (total-sales) accuracy on a held-out 12-week test window:

| Model | MAE | RMSE | MAPE |
|---|---|---|---|
| Seasonal naive (same week last year) | 101,844 | 107,226 | 46.8% |
| Naive (repeat last week) | 78,306 | 87,304 | 34.8% |
| ETS (independent) | 38,819 | 48,869 | 16.9% |
| **ETS, MinT-reconciled** | **33,770** | **41,118** | **15.5%** |

- Reconciliation cut aggregate MAE by about 13% relative to plain ETS and roughly halved the error of the naive baseline.
- Individual categories are much noisier (MAPE from about 15% for the largest categories to about 96% for sparse ones). Treat category forecasts as directional and the aggregate forecast as the planning number.

> To regenerate these figures for your own run, use `targets::tar_read(forecast_accuracy)`. Exact values depend on the train/test configuration set in `_targets.R`.

### Retention: first-order repeat-purchase propensity

| Metric | Default threshold (0.5) | F1-tuned threshold (0.08) |
|---|---|---|
| True positives | 1 | 75 |
| False positives | 0 | 120 |
| False negatives | 596 | 522 |
| Precision | not meaningful | 0.385 |
| Recall | 0.002 | 0.126 |
| F1 | about 0.003 | 0.189 |

- AUC is about 0.60: modest, real signal, not a strong classifier.
- At the tuned threshold, flagged customers repeat at about 12 times the base rate (38.5% against roughly 3%).
- All predictors are significant at p < 0.01. Review sentiment and delivery delay matter more than order value.

---

## Features

- **Relational ETL** across 9 tables with fan-out-safe joins and referential-integrity validation.
- **Hierarchical forecasting**: category and total series forecast together and reconciled so they sum correctly.
- **Honest benchmarking** against naive and seasonal-naive baselines on genuinely held-out weeks.
- **Repeat-purchase model** built only from first-order information, so no future data leaks into the features.
- **Evidence-based threshold selection** through a precision/recall/F1 sweep instead of a default cutoff.
- **Live-feed simulation** using the real final 8 weeks of data, never synthetic records. Models are trained only on data before that window.
- **Synchronized dashboard**: one week slider drives both the sales-forecast view and the customer-scoring view.
- **Reproducible by construction**: cached pipeline, pinned dependencies, documented functions.

---

## Dataset

**Olist Brazilian E-Commerce Public Dataset**
Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

| Fact | Value |
|---|---|
| Orders | 99,441 |
| Unique customers | 95,560 |
| Date range | Sep 2016 to Oct 2018 |
| Customers with exactly one order | 96.9% |
| Customers with 3+ orders | 236 (0.25%) |
| Tables | 9 (orders, order items, customers, payments, reviews, products, sellers, geolocation, category translation) |

Seven of the nine tables feed the current models. `sellers` and `geolocation` are loaded but not yet used (see the [Roadmap](#roadmap)).

The raw CSVs are **not** committed to this repository. You download them yourself (see [Getting started](#getting-started)).

---

## Dashboard preview

| Pipeline graph | Forecast replay | Customer scoring |
|---|---|---|
| ![Pipeline](assets/pipeline-graph.png) | ![Forecast replay](assets/forecast-replay.png) | ![Customer scoring](assets/customer-scoring.png) |

**Sales Forecast tab.** Drag or play the week slider to reveal held-out weeks one at a time. The chart overlays historical sales, the model's forecast, and the actuals as they appear, with a table of per-week forecast error underneath.

**Customer Scoring tab.** The same slider reveals newly arriving customers, each pre-scored by the repeat-purchase model, ranked by predicted probability and flagged against the tuned threshold.

---

## Getting started

### Prerequisites

| Tool | Version | Link |
|---|---|---|
| R | 4.4 or newer (developed on 4.6) | https://cran.r-project.org/ |
| RStudio Desktop | current | https://posit.co/download/rstudio-desktop/ |
| Git | current | https://git-scm.com/downloads |

Node.js is only needed later for the static (shinylive) deployment, not for running the project locally.

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/retailDemandIntelligence.git
cd retailDemandIntelligence
```

Open `retailDemandIntelligence.Rproj` in RStudio. Always open the project through this file so paths and `renv` resolve correctly.

### 2. Restore the exact package versions

In the RStudio Console:

```r
renv::restore()
```

This installs the package versions recorded in `renv.lock`. It can take several minutes the first time.

### 3. Quick start: run the dashboard only

The final pipeline outputs the app needs are committed in `inst/app/data/`, so you can launch the dashboard without downloading any data or running the pipeline:

```r
golem::run_dev()
```

### 4. Full reproduction from raw data

**a. Download the dataset.** Get it from Kaggle (free account required): https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
Extract all 9 CSV files into `data/raw/`. You should end up with:

```
data/raw/
├── olist_customers_dataset.csv
├── olist_geolocation_dataset.csv
├── olist_order_items_dataset.csv
├── olist_order_payments_dataset.csv
├── olist_order_reviews_dataset.csv
├── olist_orders_dataset.csv
├── olist_products_dataset.csv
├── olist_sellers_dataset.csv
└── product_category_name_translation.csv
```

Check they are found:

```r
list.files("data/raw")
```

**b. Run the pipeline:**

```r
library(targets)
tar_make()
```

The first run takes roughly a minute. Re-running `tar_make()` with nothing changed finishes in well under a second, because every unchanged step is skipped.

If the background R process crashes on your machine, run the pipeline in your current session instead:

```r
tar_make(callr_function = NULL)
```

**c. Inspect results:**

```r
tar_load(forecast_accuracy)
tar_load(threshold_comparison)
tar_load(final_confusion_matrix)

forecast_accuracy
threshold_comparison
final_confusion_matrix

tar_visnetwork()   # interactive dependency graph
```

**d. Export the artifacts the app reads:**

```r
source("R/data_export.R")
export_dashboard_data()
```

**e. Launch the dashboard:**

```r
golem::run_dev()
```

### Daily workflow tips

- Install new packages with `install.packages("pkg")`, then run `renv::snapshot()` so the lockfile stays accurate.
- After changing any pipeline output, rerun `tar_make()` and then `export_dashboard_data()` so the app sees the new results.
- In Git Bash on Windows, wrap any path containing spaces in quotes. In R, use forward slashes (`C:/Users/...`).

---

## Project structure

```
retailDemandIntelligence/
├── _targets.R                   # pipeline definition (the dependency graph)
├── R/
│   ├── data_ingest.R            # load + validate the 9 raw tables
│   ├── data_transform.R         # order_level, customer_level, category_week tables
│   ├── forecasting.R            # hierarchy build, ETS + MinT, baselines, accuracy
│   ├── retention.R              # review features, logistic model, threshold tuning
│   ├── simulation.R             # historical vs. held-out split, scored customer feed
│   ├── data_export.R            # writes final artifacts for the app
│   ├── app_ui.R                 # top-level UI with the shared week slider
│   ├── app_server.R             # loads artifacts, wires modules together
│   ├── mod_forecast_replay.R    # Sales Forecast tab
│   ├── mod_customer_scoring.R   # Customer Scoring tab
│   └── run_app.R
├── data/
│   ├── raw/                     # downloaded CSVs (gitignored)
│   └── processed/               # regenerable outputs (gitignored)
├── inst/app/data/               # committed .rds artifacts the dashboard reads
├── assets/                      # README images
├── dev/                         # golem development scripts
├── renv.lock                    # pinned package versions
├── DESCRIPTION / NAMESPACE      # R package metadata
└── README.md
```

---

## Pipeline targets

| Target | What it produces |
|---|---|
| `raw_data_files` | Tracks the raw CSV files on disk |
| `olist` | Named list of the 9 raw tables, validated |
| `order_level` | One row per order: item and payment totals, customer, delivery timing |
| `customer_level` | One row per unique customer: first/last purchase, order count, spend, recency |
| `category_week` | Weekly sales by product category |
| `category_week_split` | Real data split into historical (training) and simulation (held-out) portions |
| `hierarchical_sales` | Category plus total hierarchy as a time-series table |
| `hierarchical_forecast` | ETS and MinT-reconciled forecasts |
| `forecast_accuracy` | MAE, RMSE, MAPE for ETS, reconciled ETS, naive, and seasonal naive |
| `review_features` | Per-customer review aggregates |
| `repeat_purchase_dataset` | Modeling table built from first-order information only |
| `repeat_purchase_model` | Fitted logistic regression, test predictions, AUC |
| `threshold_sweep` / `threshold_plot` | Precision, recall, F1 across thresholds, and the chart |
| `best_threshold` | The F1-optimal threshold |
| `threshold_comparison` | Default versus tuned threshold, side by side |
| `final_confusion_matrix` | Confusion matrix at the tuned threshold |
| `customer_simulation_feed` / `customer_simulation_scored` | Held-out new customers, then scored by the model |

---

## Tech stack

| Area | Tools |
|---|---|
| Language | R |
| App structure | `golem` (Shiny app as an R package), `shiny`, `ggplot2` |
| Pipeline and reproducibility | `targets`, `renv`, Git and GitHub |
| Data wrangling | `dplyr`, `tidyr`, `tibble` |
| Forecasting | `tsibble`, `fable`, `fabletools` |
| Classification and evaluation | base `glm`, `pROC` |
| Diagnostics | `visNetwork` (pipeline graph) |

---

## Validation and data-quality findings

These are documented on purpose. They are the reason the headline numbers can be trusted.

- **Referential integrity was verified, not assumed.** Order, customer, and payment joins preserved the expected row counts (99,441 orders in, 99,441 rows out), confirming no fan-out.
- **The final weeks of the dataset are incomplete.** The collection window ends mid-week, so the last two to three weeks show a fake collapse in sales. This first surfaced as an absurd MAPE of over 12,000%. It was diagnosed by inspecting the weekly totals directly, then fixed by trimming the incomplete tail.
- **A plausible fix was tested and rejected.** Excluding the sparse launch months (Sep to Dec 2016) seemed sensible, but held-out accuracy got worse (aggregate MAPE rose from about 15.5% to about 24.6%, and the naive model overtook the reconciled one). The change was reverted.
- **A textbook model was ruled out by the data.** BTYD / Pareto-NBD customer-lifetime modeling needs repeat-purchase timing, and 96.9% of customers bought once. The problem was reframed as first-purchase-to-repeat classification, which the data can support.
- **The default 0.5 threshold was unusable.** With a roughly 3% positive class, it caught 1 of 597 repeat buyers. Tuning the threshold on F1 fixed this.
- **Leakage was designed out.** Retention features come only from each customer's first order.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `could not find function "tar_make"` (or `tar_load`, `autoplot`) | The package is not loaded in your session. Run `library(targets)` first. |
| `Warning: Targets and globals must have unique names` | Objects with target names exist in your global environment. Run `rm(list = ls())`. Turn off *Tools → Global Options → General → Restore .RData into workspace at startup* to stop it recurring. |
| `callr subprocess failed: could not start R` | The background process crashed. Retry, or run `tar_make(callr_function = NULL)`. |
| `duplicated target names` | A target is declared twice in `_targets.R`. Search the file for the name and remove one copy. |
| Pipeline says everything is skipped after you edited a function | Confirm the file was actually saved before running `tar_make()`. |
| `Can't select columns that don't exist` on `tar_load()` | The target has not been built yet. Run `tar_make()` first. |
| Install prompt swallows your next commands | Paste one command at a time when R is waiting on a `[Y/n]` prompt. |
| `autoplot` deprecation warning | Plotting moved to `ggtime`. Use `library(ggtime)`. The warning is harmless. |
| `Non-integer lag orders for random walk models` | Harmless. A one-year lag measured in weeks is rounded to 52. |

---

## Limitations

- **Early-growth window.** The data covers a young marketplace growing quickly, which is why seasonal-naive performs worst. Results should not be assumed to transfer to a mature retailer without revalidation.
- **Category-level forecasts are noisy.** Only the aggregate forecast is reliable enough to plan against.
- **Modest classifier strength.** AUC of about 0.60 means a real but limited signal. The value is in prioritization (about 12 times lift), not in confident individual predictions.
- **Review data is order-grain.** For the 97% of customers with one order, the average review score is simply that order's score, not a satisfaction trend.
- **`sellers` and `geolocation` are unused.** Whether delivery delay is a controllable lever or a proxy for shipping distance is not yet separated.
- **Simulation is a replay.** It re-plays real held-out history. It is not a connection to a live system.

---

## Roadmap

- [x] Relational ETL and validation
- [x] Hierarchical forecasting with baselines and accuracy evaluation
- [x] Repeat-purchase model with threshold tuning
- [x] Live-feed simulation from real held-out data
- [x] Dashboard: Sales Forecast and Customer Scoring tabs
- [ ] Dashboard: Model Summary tab (accuracy table, threshold chart, confusion matrix, coefficients)
- [ ] Seller concentration and shipping-distance analysis using `sellers` and `geolocation`
- [ ] Multicollinearity check (VIF) and interaction terms for the retention model
- [ ] Cohort retention curves
- [ ] Unit tests with `testthat` and GitHub Actions CI
- [ ] Static deployment with `shinylive` on Vercel

---

## Acknowledgments

- Olist, for releasing the dataset publicly: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
- The `tidyverts` ecosystem (`tsibble`, `fable`, `fabletools`) and the forecasting research behind hierarchical reconciliation by Rob Hyndman and collaborators.
- The `targets`, `renv`, and `golem` maintainers for making reproducible R projects practical.

---

## Author and license

Built by Monish D as a Programming for Data Science course project.

Released under the MIT License.
