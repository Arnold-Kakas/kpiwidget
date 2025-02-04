#' Create an interactive KPI widget for Quarto dashboards with Crosstalk support.
#'
#' This function computes and displays a key performance indicator (KPI) based on a
#' variety of statistics. The data can be filtered using formulas.
#' In addition, a comparison mode can be applied by specifying the \code{comparison}
#' parameter as either \code{"ratio"} or \code{"share"}. For example, if
#' \code{comparison = "ratio"} and \code{kpi = "sum"} (with a column indicating sales),
#' the widget will calculate the ratio of sales between two groups defined by \code{group1}
#' and \code{group2}.
#'
#' @param data A \code{crosstalk::SharedData} object.
#' @param kpi A character string specifying the metric to compute.
#'   Options are: \code{"sum"}, \code{"mean"}, \code{"min"}, \code{"max"},
#'   \code{"count"}, \code{"distinctCount"}, \code{"duplicates"}. The default is count.
#' @param comparison Optional. A character string indicating a comparison mode.
#'   Options are \code{"ratio"} or \code{"share"}. If not provided (NULL), no comparison is performed.
#' @param column A column name (as a string) to be used for numeric aggregation.
#'   In standard mode this is required. In comparison mode, if provided it is used for both groups;
#'   if omitted, counts are used.
#' @param selection A one-sided formula to filter rows.
#' @param group1 For comparison mode: a one-sided formula defining group 1.
#'   This is required in comparison mode.
#' @param group2 For comparison mode: a one-sided formula defining group 2.
#'   For \code{comparison = "ratio"}, if not provided, it defaults to the complement of group1.
#'   For \code{comparison = "share"}, if not provided, it defaults to all rows.
#' @param decimals Number of decimals to round the computed result. Default: 1.
#' @param big_mark Character to be used as the thousands separator. Default: " ".
#' @param prefix A string to be prepended to the displayed value.
#' @param suffix A string to be appended to the displayed value.
#' @param width Widget width (passed to \code{htmlwidgets::createWidget}).
#' @param height Widget height.
#' @param elementId Optional element ID for the widget.
#' @param group crosstalk group name. Typically provided by the SharedData object.
#'
#' @returns An object of class \code{htmlwidget} that will print itself into an HTML page.
#'
#' @examples
#' # Standard KPI example:
#' mtcars_shared <- crosstalk::SharedData$new(mtcars, key = ~ 1:nrow(mtcars), group = "mtcars_group")
#' kpiwidget(mtcars_shared, kpi = "mean", column = "mpg", decimals = 1, suffix = " mpg", height = "25px
#' )
#'
#' # Comparison (ratio) example: ratio of mean mpg between two groups.
#' kpiwidget(mtcars_shared,
#'   kpi = "mean", comparison = "ratio", column = "mpg",
#'   group1 = ~ cyl == 4, group2 = ~ cyl == 6,  height = "25px
#' )
#'
#' @export
kpiwidget <- function(
    data,
    kpi = c("count", "distinctCount", "duplicates", "sum", "mean", "min", "max"),
    comparison = NULL,
    column = NULL,
    selection = NULL,
    group1 = NULL,
    group2 = NULL,
    decimals = 1,
    big_mark = " ",
    prefix = NULL,
    suffix = NULL,
    width = NULL,
    height = NULL,
    elementId = NULL,
    group = NULL) {
  # -------------------------------------------#
  # Check if data is a SharedData object from Crosstalk
  # more details: https://rstudio.github.io/crosstalk/authoring.html#Modify_the_R_binding
  # -------------------------------------------#
  # -------------------------------------------#
  # Check if data is a SharedData object from Crosstalk
  # -------------------------------------------#
  if (crosstalk::is.SharedData(data)) {
    key <- data$key()
    group <- data$groupName()
    data <- data$origData()
  } else {
    warning("kpiWidget can be used only with a Crosstalk SharedData object!")
    return(NULL)
  }

  # Ensure 'kpi' is one of the allowed values.
  kpi_list <- c("count", "distinctCount", "duplicates", "sum", "mean", "min", "max")
  kpi <- match.arg(kpi, kpi_list)

  # If comparison mode is active, validate it.
  if (!is.null(comparison)) {
    comparison <- match.arg(comparison, choices = c("ratio", "share"))
  }

  # -------------------------------------------#
  # Check provided column(s)
  # -------------------------------------------#
  if (is.null(comparison)) {
    # Standard KPI mode: require 'column'
    if (is.null(column)) {
      warning("Column must be provided for standard KPI calculation.")
      return(NULL)
    }
    if (!(column %in% colnames(data))) {
      warning("No '", column, "' column in data.")
      return(NULL)
    }
  } else {
    # Comparison mode: require group1 filter.
    if (is.null(group1)) {
      warning("group1 filter must be provided in comparison mode.")
      return(NULL)
    }
    # In comparison mode, if 'column' is provided, verify it exists.
    if (!is.null(column) && !(column %in% colnames(data))) {
      warning("No '", column, "' column in data.")
      return(NULL)
    }
  }


  # -------------------------------------------#
  # Apply overall selection filter if provided.
  # -------------------------------------------#
  if (!is.null(selection)) {
    if (inherits(selection, "formula")) {
      if (length(selection) != 2L) {
        warning("Unexpected two-sided formula in selection: ", deparse(selection))
        return(NULL)
      } else {
        selection <- eval(selection[[2]], data, environment(selection))
      }
    }
    data <- data[selection, , drop = FALSE]
    if (!is.null(key)) {
      key <- key[selection]
    }
  }

  # Initialize objects for passing to JavaScript.
  data_value <- NULL # for standard aggregations
  group1_filter <- NULL
  group2_filter <- NULL
  group1_values <- NULL
  group2_values <- NULL

  # -------------------------------------------#
  # Prepare data based on mode.
  # -------------------------------------------#
  if (is.null(comparison)) {
    # Standard KPI mode.
    data_value <- data[[column]]
  } else {
    # Comparison mode.
    # Even in comparison mode, if the user provides a column,
    # we want to aggregate that column.
    if (!is.null(column)) {
      data_value <- data[[column]]
    } else {
      # If no column is provided, default to counting (each row counts as 1)
      data_value <- rep(1, nrow(data))
    }

    # Evaluate group1 filter (must be a one-sided formula).
    if (!inherits(group1, "formula")) {
      warning("group1 must be a one-sided formula. Remove single/double quotes if you used them.")
      return(NULL)
    }
    if (length(group1) != 2L) {
      warning("Unexpected two-sided formula in group2: ", deparse(group1))
      return(NULL)
    }

    group1_filter <- eval(group1[[2]], data, environment(group1))
    group1_filter[is.na(group1_filter)] <- FALSE

    # Evaluate group2 filter (must be a one-sided formula).
    if (!is.null(group2)) {
      if (!inherits(group2, "formula")) {
        warning("group2 must be a one-sided formula or remain blank. Remove single/double quotes if you used them.")
        return(NULL)
      }
      if (length(group2) != 2L) {
        warning("Unexpected two-sided formula in group2: ", deparse(group2))
        return(NULL)
      }
      group2_filter <- eval(group2[[2]], data, environment(group2))
      group2_filter[is.na(group2_filter)] <- FALSE
    } else {
      if (comparison == "ratio") {
        # Default: group2 is the complement of group1.
        group2_filter <- !group1_filter
      } else if (comparison == "share") {
        # Default: all rows.
        group2_filter <- rep(TRUE, nrow(data))
      }
    }
  }

  # -------------------------------------------#
  # Prepare data to pass to JavaScript.
  # -------------------------------------------#
  x <- list(
    data = data_value,
    key = key,
    group1_filter = group1_filter,
    group2_filter = group2_filter,
    settings = list(
      kpi = kpi,
      comparison = comparison,
      decimals = decimals,
      big_mark = big_mark,
      prefix = prefix,
      suffix = suffix,
      crosstalk_group = group
    )
  )

  # Create the htmlwidget.
  htmlwidgets::createWidget(
    name = "kpiwidget", # Must match the widget name in your JavaScript.
    x,
    width = width,
    height = height,
    package = "kpiwidget", # Your package name.
    elementId = elementId,
    dependencies = crosstalk::crosstalkLibs()
  )
}
