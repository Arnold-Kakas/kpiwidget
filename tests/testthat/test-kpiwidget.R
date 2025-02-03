test_that("Standard mode returns an htmlwidget with correct data", {
  sd <- crosstalk::SharedData$new(mtcars)
  res <- kpiwidget(sd, kpi = "mean", column = "mpg", decimals = 1,
                      prefix = "", suffix = " mpg")

  # Check that the returned object is an htmlwidget
  expect_s3_class(res, "htmlwidget")

  # Check that the data sent to JS equals the 'mpg' column from mtcars
  expect_equal(res$x$data, mtcars[["mpg"]])

  # Check settings: kpi should be "mean" and no comparison mode
  expect_equal(res$x$settings$kpi, "mean")
  expect_null(res$x$settings$comparison)
})

test_that("Comparison mode (share) returns an htmlwidget with proper filters", {
  sd <- crosstalk::SharedData$new(mtcars)
  res <- kpiwidget(sd, kpi = "sum", comparison = "share", column = "mpg",
                      group1 = ~ cyl == 4)

  expect_s3_class(res, "htmlwidget")
  expect_equal(res$x$settings$comparison, "share")
  expect_equal(res$x$settings$kpi, "sum")

  # group1_filter should be a logical vector of length equal to number of rows
  expect_true(is.logical(res$x$group1_filter))
  expect_equal(length(res$x$group1_filter), nrow(mtcars))

  # In share mode, if group2 is not provided, group2_filter should be all TRUE.
  expect_equal(res$x$group2_filter, rep(TRUE, nrow(mtcars)))
})

test_that("Comparison mode (ratio) returns an htmlwidget with proper filters", {
  sd <- crosstalk::SharedData$new(mtcars)
  res <- kpiwidget(sd, kpi = "sum", comparison = "ratio", column = "mpg",
                      group1 = ~ cyl == 4)

  expect_s3_class(res, "htmlwidget")
  expect_equal(res$x$settings$comparison, "ratio")
  expect_equal(res$x$settings$kpi, "sum")

  # Check that group1_filter and group2_filter are logical and have correct length
  expect_true(is.logical(res$x$group1_filter))
  expect_true(is.logical(res$x$group2_filter))
  expect_equal(length(res$x$group1_filter), nrow(mtcars))
  expect_equal(length(res$x$group2_filter), nrow(mtcars))

  # In ratio mode, default group2_filter should be the complement of group1_filter.
  expect_equal(res$x$group2_filter, !res$x$group1_filter)
})

test_that("Non-SharedData input returns NULL with warning", {
  expect_warning(
    res <- kpiwidget(mtcars, kpi = "mean", column = "mpg", decimals = 1,
                     prefix = "", suffix = " mpg"),
    "kpiWidget can be used only with a Crosstalk SharedData object!"
  )
  expect_null(res)
})

test_that("Nonexistent column returns NULL with warning", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "mean", column = "nonexistent", decimals = 1,
                     prefix = "", suffix = " mpg"),
    "No 'nonexistent' column in data."
  )
  expect_null(res)
})


test_that("Nonexistent column returns NULL with warning in comparison mode", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "mean", column = "nonexistent", decimals = 1,
                     comparison = "share", group1 = ~ cyl == 4),
    "No 'nonexistent' column in data."
  )
  expect_null(res)
})

test_that("Missing group1 in comparison mode returns NULL with warning", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "sum", comparison = "share", column = "mpg"),
    "group1 filter must be provided in comparison mode."
  )
  expect_null(res)
})

test_that("Selection filter works correctly", {
  sd <- crosstalk::SharedData$new(mtcars)
  res <- kpiwidget(sd, kpi = "mean", column = "mpg",
                      selection = ~ mpg > 20, decimals = 1)

  expect_s3_class(res, "htmlwidget")

  # Manually filter mtcars by mpg > 20.
  filtered <- mtcars[mtcars$mpg > 20, , drop = FALSE]
  expect_equal(res$x$data, filtered[["mpg"]])
})

test_that("Missing column returns NULL with warning", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "sum"),
    "Column must be provided for standard KPI calculation."
  )
  expect_null(res)
})

test_that("Selection must be one-sided formula", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "sum", column = "mpg", selection = mpg ~ mpg > 20),
    "Unexpected two-sided formula in selection: mpg ~ mpg > 20"
  )
  expect_null(res)
})

test_that("group1 wrong format", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "sum", column = "mpg", comparison = "ratio",
                     group1 = "~ cyl > 4"),
    "group1 must be a one-sided formula. Remove single/double quotes if you used them."
  )
  expect_null(res)
})

test_that("group1 must be one-sided formula", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "sum", column = "mpg", comparison = "ratio",
                     group1 = cyl ~ cyl > 4),
    "Unexpected two-sided formula in group2: cyl ~ cyl > 4"
  )
  expect_null(res)
})

test_that("group2 wrong format", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "sum", column = "mpg", comparison = "ratio",
                     group1 = ~ cyl > 4, group2 = "~ cyl == 4"),
    "group2 must be a one-sided formula or remain blank. Remove single/double quotes if you used them."
  )
  expect_null(res)
})

test_that("group2 must be one-sided formula", {
  sd <- crosstalk::SharedData$new(mtcars)
  expect_warning(
    res <- kpiwidget(sd, kpi = "sum", column = "mpg", comparison = "ratio",
                     group1 = ~ cyl > 4, group2 = cyl ~ cyl == 4),
    "Unexpected two-sided formula in group2: cyl ~ cyl == 4"
  )
  expect_null(res)
})


test_that("Comparison mode (ratio), group2 is one-sided formula, returns an htmlwidget with proper filters", {
  sd <- crosstalk::SharedData$new(mtcars)

  res <- kpiwidget(sd, kpi = "sum", column = "mpg", comparison = "ratio",
                     group1 = ~ cyl > 4, group2 = ~ cyl == 4)

  expect_s3_class(res, "htmlwidget")
  expect_equal(res$x$settings$comparison, "ratio")
  expect_equal(res$x$settings$kpi, "sum")

  # Check that group1_filter and group2_filter are logical and have correct length
  expect_true(is.logical(res$x$group1_filter))
  expect_true(is.logical(res$x$group2_filter))
  expect_equal(length(res$x$group1_filter), nrow(mtcars))
  expect_equal(length(res$x$group2_filter), nrow(mtcars))
})


test_that("Comparison mode (ratio) without specified column will return count by default (each row has value == 1). No error is thrown", {
  sd <- crosstalk::SharedData$new(mtcars)

  res <- kpiwidget(sd, kpi = "sum", comparison = "ratio",
                   group1 = ~ cyl > 4, group2 = ~ cyl == 4)

  expect_s3_class(res, "htmlwidget")
  expect_equal(res$x$settings$comparison, "ratio")
  expect_equal(res$x$settings$kpi, "sum")

  # Check that group1_filter and group2_filter are logical and have correct length
  expect_true(is.logical(res$x$group1_filter))
  expect_true(is.logical(res$x$group2_filter))
  expect_equal(length(res$x$group1_filter), nrow(mtcars))
  expect_equal(length(res$x$group2_filter), nrow(mtcars))
})
