library(dplyr)
library(tsibble)
library(fable)
library(fabletools)
#' Reduce category_week to top N categories + an "other" bucket,
#' then build a hierarchical (category + total) tsibble ready for forecasting.
#' Drops the last `trim_weeks` of data, since the final period(s) in this
#' dataset are typically incomplete (data collection cutoff mid-week),
#' which would otherwise distort both model fitting and accuracy evaluation.
#'
#' @param category_week data.frame from build_category_week_table()
#' @param top_n number of top categories to keep individually
#' @param trim_weeks number of most recent weeks to drop as incomplete
#' @return a tsibble with an aggregated hierarchy (categories + Total)
#' @export
prepare_hierarchical_sales <- function(category_week, top_n = 10, trim_weeks = 3) {
  
  top_categories <- category_week %>%
    group_by(category) %>%
    summarise(total = sum(total_sales, na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(total)) %>%
    slice_head(n = top_n) %>%
    pull(category)
  
  max_week <- max(category_week$order_week, na.rm = TRUE)
  cutoff_week <- max_week - (trim_weeks * 7)
  
  category_week %>%
    filter(!is.na(category), order_week <= cutoff_week) %>%
    mutate(category = ifelse(category %in% top_categories, category, "other")) %>%
    group_by(order_week, category) %>%
    summarise(total_sales = sum(total_sales, na.rm = TRUE), .groups = "drop") %>%
    as_tsibble(index = order_week, key = category) %>%
    fill_gaps(total_sales = 0) %>%
    aggregate_key(category, total_sales = sum(total_sales, na.rm = TRUE))
}
#' Fit ETS models per series, forecast, and reconcile the hierarchy with MinT
#'
#' @param hierarchical_data tsibble from prepare_hierarchical_sales()
#' @param horizon number of weeks ahead to forecast
#' @return a list with the fitted models and the reconciled forecast object
#' @export
fit_hierarchical_forecast <- function(hierarchical_data, horizon = 12) {
  
  fit <- hierarchical_data %>%
    model(ets = ETS(total_sales)) %>%
    reconcile(ets_reconciled = min_trace(ets))
  
  fc <- fit %>% forecast(h = horizon)
  
  list(fit = fit, forecast = fc)
}

#' Evaluate forecast accuracy via a simple train/test split
#'
#' Fits models only on data before the cutoff, forecasts forward across
#' the held-out weeks, then compares forecasts against actual values
#' using standard accuracy metrics (per series, per model).
#'
#' @param hierarchical_data tsibble from prepare_hierarchical_sales()
#' @param test_weeks number of most recent weeks to hold out for testing
#' @return a tibble of accuracy metrics (.model, category, MAE, RMSE, MAPE, etc.)
#' @export
evaluate_hierarchical_forecast <- function(hierarchical_data, test_weeks = 12) {
  
  max_week <- max(hierarchical_data$order_week)
  cutoff <- max_week - (test_weeks * 7)
  
  train <- hierarchical_data %>% filter(order_week <= cutoff)
  test  <- hierarchical_data %>% filter(order_week > cutoff)
  
  fit <- train %>%
    model(
      ets    = ETS(total_sales),
      naive  = NAIVE(total_sales),
      snaive = SNAIVE(total_sales ~ lag(52))
    ) %>%
    reconcile(ets_reconciled = min_trace(ets))
  
  fc <- fit %>% forecast(h = test_weeks)
  
  fabletools::accuracy(fc, test) %>%
    arrange(.model, category)
}