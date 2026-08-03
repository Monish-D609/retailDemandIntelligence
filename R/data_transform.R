library(dplyr)

#' Build one row per order: totals, item counts, payment info, timing
#'
#' @param data named list from load_raw_olist_data()
#' @return data.frame, one row per order_id
#' @export
build_order_level_table <- function(data) {
  
  items_agg <- data$order_items %>%
    group_by(order_id) %>%
    summarise(
      n_items       = n(),
      item_total    = sum(price, na.rm = TRUE),
      freight_total = sum(freight_value, na.rm = TRUE),
      .groups = "drop"
    )
  
  payments_agg <- data$payments %>%
    group_by(order_id) %>%
    summarise(
      payment_value        = sum(payment_value, na.rm = TRUE),
      n_payment_methods     = n_distinct(payment_type),
      primary_payment_type  = payment_type[which.max(payment_value)],
      max_installments      = max(payment_installments, na.rm = TRUE),
      .groups = "drop"
    )
  
  data$orders %>%
    left_join(items_agg, by = "order_id") %>%
    left_join(payments_agg, by = "order_id") %>%
    left_join(
      data$customers %>% select(customer_id, customer_unique_id, customer_state, customer_city),
      by = "customer_id"
    ) %>%
    mutate(
      order_purchase_timestamp      = as.POSIXct(na_if(order_purchase_timestamp, ""), format = "%Y-%m-%d %H:%M:%S"),
      order_delivered_customer_date = as.POSIXct(na_if(order_delivered_customer_date, ""), format = "%Y-%m-%d %H:%M:%S"),
      order_estimated_delivery_date = as.POSIXct(na_if(order_estimated_delivery_date, ""), format = "%Y-%m-%d %H:%M:%S"),
      delivery_days = as.numeric(difftime(order_delivered_customer_date, order_purchase_timestamp, units = "days")),
      delivery_delay_days = as.numeric(difftime(order_delivered_customer_date, order_estimated_delivery_date, units = "days")),
      order_week = as.Date(cut(order_purchase_timestamp, "week"))
    )
}

#' Build one row per unique customer: RFM-style aggregates for CLV modeling
#'
#' @param order_level data.frame from build_order_level_table()
#' @return data.frame, one row per customer_unique_id
#' @export
build_customer_level_table <- function(order_level) {
  
  reference_date <- max(order_level$order_purchase_timestamp, na.rm = TRUE)
  
  order_level %>%
    filter(order_status != "canceled") %>%
    group_by(customer_unique_id) %>%
    summarise(
      first_purchase   = min(order_purchase_timestamp, na.rm = TRUE),
      last_purchase    = max(order_purchase_timestamp, na.rm = TRUE),
      n_orders         = n_distinct(order_id),
      total_spend      = sum(item_total, na.rm = TRUE),
      avg_order_value  = mean(item_total, na.rm = TRUE),
      customer_state   = first(customer_state),
      .groups = "drop"
    ) %>%
    mutate(
      recency_days    = as.numeric(difftime(reference_date, last_purchase, units = "days")),
      tenure_days     = as.numeric(difftime(last_purchase, first_purchase, units = "days")),
      is_repeat_buyer = n_orders > 1
    )
}

#' Build weekly sales aggregated by product category, for forecasting
#'
#' @param data named list from load_raw_olist_data()
#' @param order_level data.frame from build_order_level_table()
#' @return data.frame with columns: order_week, category, total_sales, n_orders
#' @export
build_category_week_table <- function(data, order_level) {
  
  category_map <- data$products %>%
    select(product_id, product_category_name) %>%
    left_join(data$category_translation, by = "product_category_name")
  
  data$order_items %>%
    left_join(category_map, by = "product_id") %>%
    left_join(
      order_level %>% select(order_id, order_week, order_status),
      by = "order_id"
    ) %>%
    filter(order_status != "canceled") %>%
    group_by(order_week, product_category_name_english) %>%
    summarise(
      total_sales = sum(price, na.rm = TRUE),
      n_orders    = n_distinct(order_id),
      .groups = "drop"
    ) %>%
    rename(category = product_category_name_english)
}