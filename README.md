
# kpiwidget

<!-- badges: start -->
<!-- badges: end -->

**kpiwidget** is an interactive HTML widget for R that displays key performance indicators (KPIs) in Quarto dashboards. This package was inspired by the [summarywidget](https://github.com/kent37/summarywidget) package and enhances its functionality by providing additional KPIs (referred to as "statistics" in summarywidget).

> **Note:** This widget is designed to work only with `crosstalk::SharedData` objects.

## Features

- **Enhanced KPI/Statistic Support:**  
  In addition to basic aggregations like sum, mean, count, min, and max, kpiwidget offers additional KPIs (distinctCount, duplicates) as well as comparison modes (ratio and share) that let you compare groups within your data.

- **Crosstalk Integration:**  
  Designed to work exclusively with `crosstalk::SharedData` objects, kpiwidget enables seamless interactive filtering and linking with other widgets on your Quarto dashboard.

## Installation

You can install the development version of **kpiwidget** from GitHub using:

```r
# Install devtools if you don't have it
install.packages("devtools")
devtools::install_github("Arnold-Kakas/kpiwidget")
```

## Usage

Before using kpiwidget, ensure your data is wrapped in a crosstalk::SharedData object:

```{r}
library(crosstalk)
library(kpiwidget)

# Wrap a data.frame in SharedData:
sd <- SharedData$new(mtcars)

# Display the mean mpg of cars with 4 cylinders.
kpiwidget(sd, 
          kpi = "mean", 
          column = "mpg",
          selection = ~ cyl == 4
          )
```

## Development

This package was developed as an enhancement of the functionality provided by summarywidget. Contributions and feedback are welcome—please open an issue or submit a pull request on GitHub.

## License

This package is available under the MIT License.
