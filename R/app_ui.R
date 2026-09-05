#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),
    fluidPage(
      titlePanel("Retail Demand Intelligence"),
      fluidRow(
        column(
          width = 6,
          sliderInput("week_step", "Simulated weeks revealed:",
                      min = 0, max = 8, value = 0, step = 1,
                      animate = animationOptions(interval = 1200))
        ),
        column(
          width = 6,
          helpText("Drag the slider or press play to reveal held-out weeks one at a time. Both tabs update together, showing real sales and newly arriving customers as that week 'happens'.")
        )
      ),
      tabsetPanel(
        tabPanel("Sales Forecast", mod_forecast_replay_ui("forecast_replay")),
        tabPanel("Customer Scoring", mod_customer_scoring_ui("customer_scoring"))
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )
  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "Retail Demand Intelligence"
    )
  )
}