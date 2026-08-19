library(targets)

#' Export final pipeline artifacts needed by the Shiny app as standalone .rds
#' files bundled inside the package, decoupling the app from the targets store
#' (required for shinylive/static deployment, and good practice generally).
#'
#' @export
export_dashboard_data <- function() {
  dir.create("inst/app/data", recursive = TRUE, showWarnings = FALSE)
  
  objects_to_export <- c(
    "category_week_split",
    "hierarchical_sales",
    "hierarchical_forecast",
    "forecast_accuracy",
    "customer_simulation_scored",
    "repeat_purchase_model",
    "threshold_sweep",
    "threshold_comparison",
    "final_confusion_matrix"
  )
  
  for (obj_name in objects_to_export) {
    obj <- tar_read_raw(obj_name)
    saveRDS(obj, file.path("inst/app/data", paste0(obj_name, ".rds")))
  }
  
  invisible(TRUE)
}