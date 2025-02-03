HTMLWidgets.widget({

  name: "kpiwidget",
  type: "output",

  factory: function(el, width, height) {

    // --- Helper KPI Functions ---
    function calcSum(arr) {
      return arr.reduce(function(acc, val) { return acc + (parseFloat(val) || 0); }, 0);
    }
    function calcMean(arr) {
      return arr.length ? calcSum(arr) / arr.length : 0;
    }
    function calcCount(arr) {
      return arr.length;
    }
    function calcDistinctCount(arr) {
      return new Set(arr).size;
    }
    function calcDuplicates(arr) {
      var counts = {};
      arr.forEach(function(v) {
        counts[v] = (counts[v] || 0) + 1;
      });
      return Object.values(counts).filter(function(c) { return c > 1; }).length;
    }
    function calcMin(arr) {
      return Math.min.apply(null, arr);
    }
    function calcMax(arr) {
      return Math.max.apply(null, arr);
    }

    // Return the appropriate KPI function.
    function getKpiFunction(kpiType) {
      switch(kpiType) {
        case "sum": return calcSum;
        case "mean": return calcMean;
        case "count": return calcCount;
        case "distinctCount": return calcDistinctCount;
        case "duplicates": return calcDuplicates;
        case "min": return calcMin;
        case "max": return calcMax;
        default:
          console.warn("Unknown KPI type:", kpiType);
          return calcCount;
      }
    }

    // --- Thousand Separator Function ---
    // This function inserts the grouping symbol (bigMark) into the integer part of the number.
    function numberWithSep(x, bigMark) {
      if (typeof x !== "string") {
        x = x.toString();
      }
      var parts = x.split(".");
      parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, bigMark);
      return parts.join(".");
    }

    // --- Number Formatting ---
    function formatNumber(value, options) {
      if (typeof value !== "number" || isNaN(value)) return "";
      var prefix = options.prefix || "";
      var suffix = options.suffix || "";
      var bigMark = options.big_mark || " ";
      var decimals = options.decimals !== undefined ? options.decimals : 0;

      // Round the number to fixed decimals.
      var fixedValue = parseFloat(value).toFixed(decimals);
      // Apply thousand separator.
      var formatted = numberWithSep(fixedValue, bigMark);
      return prefix + formatted + suffix;
    }

    // --- Main Update Function ---
    // In standard mode, apply the KPI function to the full data.
    // In comparison mode, filter the data using the boolean arrays,
    // compute aggregates for each group, then compute either a ratio or a share.
    function updateDisplay(data, group1_filter, group2_filter, settings) {
      var kpiFunc = getKpiFunction(settings.kpi);
      var result;

      if (!settings.comparison) {
        // Standard mode: compute KPI over all data.
        result = kpiFunc(data);
      } else {
        // Comparison mode: split data into two groups.
        var group1Data = [];
        var group2Data = [];
        for (var i = 0; i < data.length; i++) {
          if (group1_filter[i]) { group1Data.push(data[i]); }
          if (group2_filter[i]) { group2Data.push(data[i]); }
        }
        var agg1 = kpiFunc(group1Data);
        var agg2 = kpiFunc(group2Data);
        if (settings.comparison === "ratio") {
          result = agg2 === 0 ? 0 : agg1 / agg2;
        } else if (settings.comparison === "share") {
          result = agg2 === 0 ? 0 : (agg1 / agg2) * 100;
        }
      }

      var formatted = formatNumber(result, settings);
      el.innerText = formatted;
    }

    // --- Data Storage for Full (Unfiltered) Values ---
    var fullData = null;
    var fullGroup1 = null;
    var fullGroup2 = null;
    var currentSettings = null;

    // --- Crosstalk Filter Subscription ---
    var ct_filter = new crosstalk.FilterHandle();

    return {
      renderValue: function(x) {
        // Ensure data is in array form.
        if (typeof x.data === "string") {
          try {
            x.data = JSON.parse(x.data);
          } catch(err) {
            console.error("Error parsing x.data:", err);
          }
        }
        if (typeof x.key === "string") {
          try {
            x.key = JSON.parse(x.key);
          } catch(err) {
            console.error("Error parsing x.key:", err);
          }
        }

        // Save full data and settings.
        fullData = x.data;
        currentSettings = x.settings;
        if (x.settings.comparison) {
          fullGroup1 = x.group1_filter;
          fullGroup2 = x.group2_filter;
        }

        // WORKAROUND: In comparison mode, if no data was provided, default to counts.
        if (x.settings.comparison && (!x.data || x.data.length === 0)) {
          console.warn("No data provided for comparison mode; defaulting to counts.");
          if (fullGroup1 && fullGroup1.length) {
            x.data = new Array(fullGroup1.length).fill(1);
            fullData = x.data;
          }
        }

        // Initial display update.
        if (!x.settings.comparison) {
          updateDisplay(fullData, null, null, x.settings);
        } else {
          updateDisplay(fullData, fullGroup1, fullGroup2, x.settings);
        }

        // Set up Crosstalk filter subscription.
        if (x.settings.crosstalk_group) {
          ct_filter.setGroup(x.settings.crosstalk_group);
        }
        ct_filter.on("change", function(e) {
          if (e.value && e.value.length > 0) {
            // e.value is expected to be an array of keys (assumed to be 1-indexed).
            var filteredIndices = e.value.map(function(k) { return parseInt(k, 10) - 1; });
            var filteredData = [];
            var filteredGroup1 = x.settings.comparison ? [] : null;
            var filteredGroup2 = x.settings.comparison ? [] : null;
            for (var i = 0; i < filteredIndices.length; i++) {
              var idx = filteredIndices[i];
              filteredData.push(fullData[idx]);
              if (x.settings.comparison) {
                filteredGroup1.push(fullGroup1[idx]);
                filteredGroup2.push(fullGroup2[idx]);
              }
            }
            updateDisplay(filteredData, filteredGroup1, filteredGroup2, x.settings);
          } else {
            // No active filter: revert to full data.
            updateDisplay(fullData, fullGroup1, fullGroup2, x.settings);
          }
        });
      },

      resize: function(width, height) {
        // No special resizing logic is needed.
      }
    };
  }
});
