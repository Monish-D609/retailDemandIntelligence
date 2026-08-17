library(dplyr)

#' Aggregate review scores to customer level, joined via order_level
#'
#' @param data named list from load_raw_olist_data()
#' @param order_level data.frame from build_order_level_table()
#' @return data.frame, one row per customer_unique_id with review aggregates
#' @export
build_review_features <- function(data, order_level) {
  data$reviews %>%
    group_by(order_id) %>%
    summarise(review_score = mean(review_score, na.rm = TRUE), .groups = "drop") %>%
    left_join(
      order_level %>% select(order_id, customer_unique_id),
      by = "order_id"
    ) %>%
    filter(!is.na(customer_unique_id)) %>%
    group_by(customer_unique_id) %>%
    summarise(
      avg_review_score = mean(review_score, na.rm = TRUE),
      min_review_score = min(review_score, na.rm = TRUE),
      had_bad_review   = as.integer(min(review_score, na.rm = TRUE) <= 2),
      .groups = "drop"
    )
}

#' Build a customer-level dataset for repeat-purchase propensity modeling.
#' Uses ONLY each customer's first order's characteristics as predictors,
#' since that's the information actually available at prediction time —
#' using later orders would leak future information (data leakage).
#'
#' @param order_level data.frame from build_order_level_table()
#' @param customer_level data.frame from build_customer_level_table()
#' @param review_features data.frame from build_review_features()
#' @return data.frame, one row per customer, ready for modeling
#' @export
build_repeat_purchase_dataset <- function(order_level, customer_level, review_features) {
  
  first_orders <- order_level %>%
    filter(order_status != "canceled") %>%
    group_by(customer_unique_id) %>%
    slice_min(order_purchase_timestamp, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(
      customer_unique_id, item_total, freight_total, n_items,
      delivery_days, delivery_delay_days, primary_payment_type,
      max_installments, customer_state
    )
  
  customer_level %>%
    select(customer_unique_id, is_repeat_buyer) %>%
    left_join(first_orders, by = "customer_unique_id") %>%
    left_join(review_features, by = "customer_unique_id") %>%
    mutate(
      is_repeat_buyer = factor(is_repeat_buyer, levels = c(FALSE, TRUE), labels = c("no", "yes")),
      had_bad_review  = ifelse(is.na(had_bad_review), 0, had_bad_review)
    ) %>%
    filter(
      !is.na(item_total), !is.na(delivery_days), !is.na(delivery_delay_days),
      !is.na(avg_review_score)
    )
}

#' Fit a logistic regression repeat-purchase propensity model,
#' evaluated via train/test split with AUC and a confusion matrix
#' (accuracy alone is misleading here due to severe class imbalance,
#' only ~3% of customers are repeat buyers).
#'
#' @param dataset data.frame from build_repeat_purchase_dataset()
#' @param test_frac fraction of data held out for testing
#' @param seed random seed for reproducible train/test split
#' @return a list with the fitted model, test predictions, confusion matrix, and AUC
#' @export
fit_repeat_purchase_model <- function(dataset, test_frac = 0.2, seed = 42) {
  
  set.seed(seed)
  n <- nrow(dataset)
  test_idx <- sample.int(n, size = floor(test_frac * n))
  train <- dataset[-test_idx, ]
  test  <- dataset[test_idx, ]
  
  model <- glm(
    is_repeat_buyer ~ item_total + freight_total + n_items + delivery_days +
      delivery_delay_days + max_installments + avg_review_score + had_bad_review,
    data = train,
    family = binomial
  )
  
  pred_prob  <- predict(model, newdata = test, type = "response")
  pred_class <- factor(ifelse(pred_prob > 0.5, "yes", "no"), levels = c("no", "yes"))
  
  confusion <- table(predicted = pred_class, actual = test$is_repeat_buyer)
  roc_obj   <- pROC::roc(response = test$is_repeat_buyer, predictor = pred_prob, levels = c("no", "yes"), direction = "<")
  auc_value <- as.numeric(pROC::auc(roc_obj))
  
  list(
    model      = model,
    test       = test,
    pred_prob  = pred_prob,
    pred_class = pred_class,
    confusion  = confusion,
    auc        = auc_value,
    roc        = roc_obj
  )
}

#' Sweep classification thresholds and compute precision, recall, and F1
#' at each, to find the threshold that best balances the two — appropriate
#' given severe class imbalance where the default 0.5 threshold performs poorly.
#'
#' @param fit_result output list from fit_repeat_purchase_model()
#' @param thresholds numeric vector of thresholds to evaluate
#' @return a tibble with precision, recall, and F1 at each threshold,
#'   plus the threshold that maximizes F1 as an attribute
#' @export
evaluate_threshold_sweep <- function(fit_result, thresholds = seq(0.01, 0.5, by = 0.01)) {
  
  actual <- fit_result$test$is_repeat_buyer
  probs  <- fit_result$pred_prob
  
  results <- lapply(thresholds, function(t) {
    pred <- factor(ifelse(probs > t, "yes", "no"), levels = c("no", "yes"))
    
    tp <- sum(pred == "yes" & actual == "yes")
    fp <- sum(pred == "yes" & actual == "no")
    fn <- sum(pred == "no"  & actual == "yes")
    
    precision <- if ((tp + fp) == 0) NA_real_ else tp / (tp + fp)
    recall    <- if ((tp + fn) == 0) NA_real_ else tp / (tp + fn)
    f1        <- if (is.na(precision) || is.na(recall) || (precision + recall) == 0) {
      NA_real_
    } else {
      2 * precision * recall / (precision + recall)
    }
    
    tibble::tibble(threshold = t, precision = precision, recall = recall, f1 = f1)
  })
  
  dplyr::bind_rows(results)
}

#' Plot precision, recall, and F1 across thresholds, marking the F1-optimal point
#'
#' @param sweep_result output of evaluate_threshold_sweep()
#' @return a ggplot object
#' @export
plot_threshold_sweep <- function(sweep_result) {
  
  best <- sweep_result %>% dplyr::slice_max(f1, n = 1, with_ties = FALSE)
  
  sweep_result %>%
    tidyr::pivot_longer(cols = c(precision, recall, f1), names_to = "metric", values_to = "value") %>%
    ggplot2::ggplot(ggplot2::aes(x = threshold, y = value, color = metric)) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_vline(xintercept = best$threshold, linetype = "dashed", color = "grey40") +
    ggplot2::annotate(
      "text", x = best$threshold, y = 0.05,
      label = paste0("best F1 @ ", best$threshold), hjust = -0.05, size = 3.2
    ) +
    ggplot2::labs(
      title = "Precision, Recall, and F1 across classification thresholds",
      subtitle = "Repeat-purchase propensity model",
      x = "Threshold", y = "Score", color = "Metric"
    ) +
    ggplot2::theme_minimal()
}


#' Compare model performance at the naive default threshold (0.5) versus
#' the F1-optimal threshold, to demonstrate the impact of threshold tuning
#' on an imbalanced classification problem.
#'
#' @param fit_result output list from fit_repeat_purchase_model()
#' @param optimal_threshold the F1-optimal threshold found via evaluate_threshold_sweep()
#' @return a tibble comparing confusion matrix outcomes and metrics at both thresholds
#' @export
compare_naive_vs_optimal_threshold <- function(fit_result, optimal_threshold) {
  
  actual <- fit_result$test$is_repeat_buyer
  probs  <- fit_result$pred_prob
  
  summarise_at_threshold <- function(t, label) {
    pred <- factor(ifelse(probs > t, "yes", "no"), levels = c("no", "yes"))
    
    tp <- sum(pred == "yes" & actual == "yes")
    fp <- sum(pred == "yes" & actual == "no")
    fn <- sum(pred == "no"  & actual == "yes")
    tn <- sum(pred == "no"  & actual == "no")
    
    precision <- if ((tp + fp) == 0) NA_real_ else tp / (tp + fp)
    recall    <- if ((tp + fn) == 0) NA_real_ else tp / (tp + fn)
    f1        <- if (is.na(precision) || is.na(recall) || (precision + recall) == 0) {
      NA_real_
    } else {
      2 * precision * recall / (precision + recall)
    }
    
    tibble::tibble(
      threshold_type = label,
      threshold = t,
      true_positives  = tp,
      false_positives = fp,
      false_negatives = fn,
      true_negatives  = tn,
      precision = round(precision, 3),
      recall    = round(recall, 3),
      f1        = round(f1, 3)
    )
  }
  
  dplyr::bind_rows(
    summarise_at_threshold(0.5, "naive (0.5)"),
    summarise_at_threshold(optimal_threshold, "optimal (F1-tuned)")
  )
}