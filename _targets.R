library(targets)

source("R/data_ingest.R")
source("R/data_transform.R")
source("R/forecasting.R")

tar_option_set(packages = c("dplyr", "tsibble", "fable", "fabletools"))

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
  
  tar_target(hierarchical_sales, prepare_hierarchical_sales(category_week, top_n = 10)),
  
  tar_target(hierarchical_forecast, fit_hierarchical_forecast(hierarchical_sales, horizon = 12)),
  
  tar_target(forecast_accuracy, evaluate_hierarchical_forecast(hierarchical_sales, test_weeks = 12))
)