#' Load all raw Olist CSVs into a named list of data frames
#'
#' @return a named list of data.frames, one per Olist table
#' @export
load_raw_olist_data <- function(raw_dir = "data/raw") {
  files <- list(
    orders          = "olist_orders_dataset.csv",
    order_items     = "olist_order_items_dataset.csv",
    customers       = "olist_customers_dataset.csv",
    payments        = "olist_order_payments_dataset.csv",
    reviews         = "olist_order_reviews_dataset.csv",
    products        = "olist_products_dataset.csv",
    sellers         = "olist_sellers_dataset.csv",
    geolocation     = "olist_geolocation_dataset.csv",
    category_translation = "product_category_name_translation.csv"
  )
  
  missing <- files[!file.exists(file.path(raw_dir, files))]
  if (length(missing) > 0) {
    stop(
      "Missing raw data files: ", paste(unlist(missing), collapse = ", "),
      "\nSee data/raw/README.md for download instructions."
    )
  }
  
  lapply(files, function(f) read.csv(file.path(raw_dir, f), stringsAsFactors = FALSE))
}

#' Basic structural validation of the loaded Olist tables
#'
#' @param data named list returned by load_raw_olist_data()
#' @return invisible TRUE if checks pass; stops with an informative error otherwise
#' @export
validate_olist_data <- function(data) {
  stopifnot(
    "orders table is empty" = nrow(data$orders) > 0,
    "order_items table is empty" = nrow(data$order_items) > 0,
    "customers table is empty" = nrow(data$customers) > 0
  )
  
  orphan_items <- setdiff(data$order_items$order_id, data$orders$order_id)
  if (length(orphan_items) > 0) {
    warning(length(orphan_items), " order_items rows reference orders not in the orders table.")
  }
  
  invisible(TRUE)
}