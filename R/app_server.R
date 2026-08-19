app_server <- function(input, output, session) {
  
  hierarchical_sales <- readRDS(app_sys("app/data/hierarchical_sales.rds"))
  hierarchical_forecast <- readRDS(app_sys("app/data/hierarchical_forecast.rds"))
  category_week_split <- readRDS(app_sys("app/data/category_week_split.rds"))
  
  mod_forecast_replay_server("forecast_replay", hierarchical_sales, hierarchical_forecast, category_week_split)
}