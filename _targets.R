library(targets)

# Load all our custom functions so targets can see them
source("R/data_ingest.R")
source("R/data_transform.R")

# Declare which packages our pipeline steps need
tar_option_set(packages = c("dplyr"))

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
  
  tar_target(category_week, build_category_week_table(olist, order_level))
)