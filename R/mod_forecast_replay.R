library(shiny)
library(dplyr)
library(ggplot2)

#' UI for the forecast replay module — steps through held-out weeks,
#' comparing the model's forecast against real actual sales as they "arrive"
#'
#' @param id module namespace id
mod_forecast_replay_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(
        width = 4,
        sliderInput(ns("week_step"), "Simulated weeks revealed:",
                    min = 0, max = 8, value = 0, step = 1, animate = animationOptions(interval = 1200)),
        helpText("Drag the slider or press play to reveal held-out weeks one at a time, comparing the model's forecast (fit on earlier data only) against real sales as they arrive.")
      ),
      column(
        width = 8,
        plotOutput(ns("replay_plot"), height = "420px")
      )
    ),
    fluidRow(
      column(width = 12, tableOutput(ns("week_summary")))
    )
  )
}

#' Server for the forecast replay module
#'
#' @param id module namespace id
#' @param hierarchical_sales tsibble of historical (pre-simulation) sales
#' @param hierarchical_forecast list with $forecast, fitted on historical data only
#' @param category_week_split list with $simulation, real held-out weekly data
mod_forecast_replay_server <- function(id, hierarchical_sales, hierarchical_forecast, category_week_split) {
  moduleServer(id, function(input, output, session) {
    
    
    
    # Build a clean aggregated actuals series from the simulation weeks
    actual_weekly <- category_week_split$simulation %>%
      group_by(order_week) %>%
      summarise(actual_sales = sum(total_sales, na.rm = TRUE), .groups = "drop") %>%
      arrange(order_week)
    
    forecast_weekly <- hierarchical_forecast$forecast %>%
      as_tibble() %>%
      filter(.model == "ets_reconciled", is_aggregated(category)) %>%
      mutate(forecast_sales = mean(total_sales)) %>%
      select(order_week, forecast_sales) %>%
      arrange(order_week)
    
    historical_weekly <- hierarchical_sales %>%
      as_tibble() %>%
      filter(is_aggregated(category)) %>%
      select(order_week, total_sales) %>%
      arrange(order_week)
    
    combined <- forecast_weekly %>%
      left_join(actual_weekly, by = "order_week")
    
    output$replay_plot <- renderPlot({
      revealed <- combined %>% slice_head(n = input$week_step)
      
      ggplot() +
        geom_line(data = historical_weekly, aes(x = order_week, y = total_sales), color = "grey40") +
        geom_line(data = combined, aes(x = order_week, y = forecast_sales), color = "#d95f5f", linetype = "dashed", linewidth = 1) +
        geom_line(data = revealed, aes(x = order_week, y = actual_sales), color = "#2c7a5e", linewidth = 1.2) +
        geom_point(data = revealed, aes(x = order_week, y = actual_sales), color = "#2c7a5e", size = 2.5) +
        labs(
          title = "Weekly aggregate sales — forecast (dashed) vs. real actuals (solid, as revealed)",
          x = NULL, y = "Total sales (R$)"
        ) +
        theme_minimal(base_size = 13)
    })
    
    output$week_summary <- renderTable({
      combined %>%
        slice_head(n = input$week_step) %>%
        mutate(
          order_week = format(order_week, "%Y-%m-%d"),
          error = actual_sales - forecast_sales,
          pct_error = round(100 * error / actual_sales, 1),
          forecast_sales = round(forecast_sales, 0),
          actual_sales = round(actual_sales, 0)
        ) %>%
        rename(Week = order_week, Forecast = forecast_sales, Actual = actual_sales, Error = error, `% Error` = pct_error)
    })
  })
}