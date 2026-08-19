library(targets)

source("R/data_ingest.R")
source("R/data_transform.R")
source("R/forecasting.R")
source("R/retention.R")
source("R/simulation.R")

tar_option_set(packages = c("dplyr", "tsibble", "fable", "fabletools", "pROC", "ggplot2", "tidyr", "tibble"))

list(
  tar_target(raw_data_files, {
    list.files("data/raw", full.names = TRUE)
  }, format = "file"),
  
  tar_target(olist, {
    d <- load_raw_olist_data()
    validate_olist_data(d)
    d
  }),
  
  tar_target(order_level, build_order_level_table(olist)),
  tar_target(customer_level, build_customer_level_table(order_level)),
  tar_target(category_week, build_category_week_table(olist, order_level)),
  
  # split real data into historical (model training) vs simulation (live-feed replay)
  tar_target(category_week_split, split_category_week_for_simulation(category_week, simulation_weeks = 8, trim_weeks = 3)),
  
  # forecasting now trains ONLY on historical, pre-simulation data
  tar_target(hierarchical_sales, prepare_hierarchical_sales(category_week_split$historical, top_n = 10, trim_weeks = 0)),
  tar_target(hierarchical_forecast, fit_hierarchical_forecast(hierarchical_sales, horizon = 8)),
  tar_target(forecast_accuracy, evaluate_hierarchical_forecast(hierarchical_sales, test_weeks = 8)),
  
  tar_target(review_features, build_review_features(olist, order_level)),
  tar_target(repeat_purchase_dataset, build_repeat_purchase_dataset(order_level, customer_level, review_features)),
  tar_target(repeat_purchase_model, fit_repeat_purchase_model(repeat_purchase_dataset)),
  tar_target(threshold_sweep, evaluate_threshold_sweep(repeat_purchase_model)),
  tar_target(threshold_plot, plot_threshold_sweep(threshold_sweep)),
  tar_target(best_threshold, {
    threshold_sweep %>% dplyr::slice_max(f1, n = 1, with_ties = FALSE) %>% dplyr::pull(threshold)
  }),
  tar_target(threshold_comparison, compare_naive_vs_optimal_threshold(repeat_purchase_model, best_threshold)),
  tar_target(final_confusion_matrix, confusion_at_threshold(repeat_purchase_model, best_threshold)),
  
  # simulation feeds for the dashboard
  tar_target(customer_simulation_feed, build_customer_simulation_feed(repeat_purchase_dataset, order_level, simulation_weeks = 8, trim_weeks = 3)),
  tar_target(customer_simulation_scored, score_customer_simulation_feed(customer_simulation_feed, repeat_purchase_model))
)