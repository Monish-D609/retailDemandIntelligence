library(shiny)
library(dplyr)

#' UI for the customer scoring module — shows new customers "arriving" each
#' simulated week, each already scored by the repeat-purchase model
#'
#' @param id module namespace id
mod_customer_scoring_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(width = 12, uiOutput(ns("week_headline")))
    ),
    fluidRow(
      column(width = 12, tableOutput(ns("customer_table")))
    )
  )
}

#' Server for the customer scoring module
#'
#' @param id module namespace id
#' @param customer_simulation_scored data.frame of simulation-window customers with predicted_repeat_prob
#' @param category_week_split list with $simulation, used to map slider steps to actual week boundaries
#' @param best_threshold numeric, the F1-optimal classification threshold from the repeat-purchase model
#' @param week_step reactive() returning the number of simulated weeks currently revealed
mod_customer_scoring_server <- function(id, customer_simulation_scored, category_week_split, best_threshold, week_step) {
  moduleServer(id, function(input, output, session) {
    
    sim_weeks <- sort(unique(category_week_split$simulation$order_week))
    
    revealed_customers <- reactive({
      if (week_step() == 0) {
        return(customer_simulation_scored[0, ])
      }
      cutoff_date <- as.POSIXct(sim_weeks[week_step()]) + (7 * 86400)
      customer_simulation_scored %>%
        filter(first_order_date <= cutoff_date) %>%
        arrange(desc(predicted_repeat_prob))
    })
    
    output$week_headline <- renderUI({
      df <- revealed_customers()
      n_high_potential <- sum(df$predicted_repeat_prob > best_threshold)
      tags$p(
        tags$strong(nrow(df)), " new customers so far · ",
        tags$strong(n_high_potential), " flagged as high repeat-potential (score above ", round(best_threshold, 2), ")"
      )
    })
    
    output$customer_table <- renderTable({
      revealed_customers() %>%
        slice_head(n = 25) %>%
        mutate(
          first_order_date = format(first_order_date, "%Y-%m-%d"),
          predicted_repeat_prob = round(predicted_repeat_prob, 3),
          item_total = round(item_total, 2),
          high_potential = ifelse(predicted_repeat_prob > best_threshold, "Yes", ""),
          customer_unique_id = paste0(substr(customer_unique_id, 1, 8), "…")
        ) %>%
        select(
          `Customer ID` = customer_unique_id,
          `First Order` = first_order_date,
          `First Order Value` = item_total,
          `Avg Review Score` = avg_review_score,
          `Delivery Delay (days)` = delivery_delay_days,
          `Repeat Probability` = predicted_repeat_prob,
          `High Potential` = high_potential
        )
    })
  })
}