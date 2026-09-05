app_server <- function(input, output, session) {
  
  hierarchical_sales <- readRDS(app_sys("app/data/hierarchical_sales.rds"))
  hierarchical_forecast <- readRDS(app_sys("app/data/hierarchical_forecast.rds"))
  category_week_split <- readRDS(app_sys("app/data/category_week_split.rds"))
  customer_simulation_scored <- readRDS(app_sys("app/data/customer_simulation_scored.rds"))
  best_threshold <- readRDS(app_sys("app/data/best_threshold.rds"))
  
  week_step_reactive <- reactive(input$week_step)
  
  mod_forecast_replay_server("forecast_replay", hierarchical_sales, hierarchical_forecast, category_week_split, week_step_reactive)
  mod_customer_scoring_server("customer_scoring", customer_simulation_scored, category_week_split, best_threshold, week_step_reactive)
}