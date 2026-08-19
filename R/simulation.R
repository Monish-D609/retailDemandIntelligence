library(dplyr)

#' Split category_week into a historical portion (for model fitting)
#' and a simulation portion (held-out real data replayed as "live" incoming
#' sales, for dashboard demonstration purposes)
#'
#' @param category_week data.frame from build_category_week_table()
#' @param simulation_weeks number of most recent complete weeks to hold out
#' @param trim_weeks number of trailing incomplete weeks to drop entirely first
#' @return list with `historical` and `simulation` data.frames
#' @export
split_category_week_for_simulation <- function(category_week, simulation_weeks = 8, trim_weeks = 3) {
  
  max_week <- max(category_week$order_week, na.rm = TRUE)
  clean_end <- max_week - (trim_weeks * 7)
  sim_start <- clean_end - (simulation_weeks * 7)
  
  clean_data <- category_week %>% filter(order_week <= clean_end)
  
  list(
    historical = clean_data %>% filter(order_week <= sim_start),
    simulation = clean_data %>% filter(order_week > sim_start) %>% arrange(order_week)
  )
}

#' Identify customers whose first purchase falls in the simulation window —
#' i.e. customers who would look like "new signups" during dashboard playback
#'
#' @param repeat_purchase_dataset data.frame from build_repeat_purchase_dataset()
#' @param order_level data.frame from build_order_level_table()
#' @param simulation_weeks number of most recent weeks treated as "live"
#' @param trim_weeks number of trailing incomplete weeks to drop
#' @return data.frame: simulation customers with their first-order date attached
#' @export
build_customer_simulation_feed <- function(repeat_purchase_dataset, order_level, simulation_weeks = 8, trim_weeks = 3) {
  
  max_date <- max(order_level$order_purchase_timestamp, na.rm = TRUE)
  clean_end <- max_date - (trim_weeks * 7 * 86400)
  sim_start <- clean_end - (simulation_weeks * 7 * 86400)
  
  first_order_dates <- order_level %>%
    filter(order_status != "canceled") %>%
    group_by(customer_unique_id) %>%
    summarise(first_order_date = min(order_purchase_timestamp, na.rm = TRUE), .groups = "drop")
  
  repeat_purchase_dataset %>%
    left_join(first_order_dates, by = "customer_unique_id") %>%
    filter(first_order_date > sim_start, first_order_date <= clean_end) %>%
    arrange(first_order_date)
}

#' Score the simulation customer feed using the already-fitted repeat-purchase
#' model, exactly as a production system would score genuinely new customers
#'
#' @param customer_simulation_feed data.frame from build_customer_simulation_feed()
#' @param repeat_purchase_model fitted model list from fit_repeat_purchase_model()
#' @return the feed with a predicted probability column attached
#' @export
score_customer_simulation_feed <- function(customer_simulation_feed, repeat_purchase_model) {
  probs <- predict(repeat_purchase_model$model, newdata = customer_simulation_feed, type = "response")
  customer_simulation_feed %>% mutate(predicted_repeat_prob = probs)
}