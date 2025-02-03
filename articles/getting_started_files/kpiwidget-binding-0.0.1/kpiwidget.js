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
      switch (kpiType) {
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
      var decimals = (options.decimals !== undefined) ? options.decimals : 0;

      var fixedValue = parseFloat(value).toFixed(decimals);
      var formatted = numberWithSep(fixedValue, bigMark);
      return prefix + formatted + suffix;
    }

    // --- Main update function for arrays ---
    // Accepts arrays of numeric data plus group booleans, then
    // applies the KPI logic and updates the text content.
    function updateDisplay(dataArr, group1Arr, group2Arr, settings) {
      var kpiFunc = getKpiFunction(settings.kpi);
      var result;

      if (!settings.comparison) {
        // Standard mode
        result = kpiFunc(dataArr);
      } else {
        // Comparison mode
        var group1Data = [];
        var group2Data = [];
        for (var i = 0; i < dataArr.length; i++) {
          if (group1Arr[i]) group1Data.push(dataArr[i]);
          if (group2Arr[i]) group2Data.push(dataArr[i]);
        }
        var agg1 = kpiFunc(group1Data);
        var agg2 = kpiFunc(group2Data);
        if (settings.comparison === "ratio") {
          result = (agg2 === 0) ? 0 : agg1 / agg2;
        } else if (settings.comparison === "share") {
          result = (agg2 === 0) ? 0 : (agg1 / agg2) * 100;
        }
      }

      el.innerText = formatNumber(result, settings);
    }

    // We'll store everything in a dictionary: key -> { value, g1, g2 }
    // That way, we can easily filter based on Crosstalk events by looking up keys.
    var dataMap = {};          // key -> {value, g1, g2}
    var settings = null;       // store settings for use in filter events
    var hasComparison = false; // indicates if comparison is active

    // Helper to rebuild arrays from a subset of dataMap
    function buildArrays(subsetObj) {
      var dataArr = [];
      var group1Arr = [];
      var group2Arr = [];
      // subsetObj is an object with the same shape as dataMap, but only for the chosen keys
      for (var k in subsetObj) {
        if (subsetObj.hasOwnProperty(k)) {
          dataArr.push(subsetObj[k].value);
          if (hasComparison) {
            group1Arr.push(subsetObj[k].g1);
            group2Arr.push(subsetObj[k].g2);
          }
        }
      }
      return { dataArr: dataArr, g1Arr: group1Arr, g2Arr: group2Arr };
    }

    // Filter an existing dictionary by a set of keys
    function filterByKeys(fullObj, keyArray) {
      var filtered = {};
      keyArray.forEach(function(k) {
        if (fullObj.hasOwnProperty(k)) {
          filtered[k] = fullObj[k];
        }
      });
      return filtered;
    }

    // The full (unfiltered) dataMap, for resetting
    var fullDataMap = {};

    // Crosstalk filter
    var ct_filter = new crosstalk.FilterHandle();
    // We could also subscribe to selection if you wish
    // var ct_sel = new crosstalk.SelectionHandle();

    return {
      renderValue: function(x) {

        // 1. Parse data if needed
        if (typeof x.data === "string") {
          try {
            x.data = JSON.parse(x.data);
          } catch (err) {
            console.error("Error parsing x.data:", err);
          }
        }
        if (typeof x.key === "string") {
          try {
            x.key = JSON.parse(x.key);
          } catch (err) {
            console.error("Error parsing x.key:", err);
          }
        }

        // 2. Save to local variables
        settings = x.settings;
        hasComparison = !!x.settings.comparison; // force boolean

        // If no data was provided in comparison mode, fallback to an array of 1s
        if (hasComparison && (!x.data || x.data.length === 0)) {
          if (x.group1_filter && x.group1_filter.length) {
            x.data = new Array(x.group1_filter.length).fill(1);
          }
        }

        // 3. Build dataMap (key -> object).
        //    If x.key is null, just use 0..N as keys
        dataMap = {};
        if (!x.key) {
          for (var i = 0; i < x.data.length; i++) {
            dataMap[i] = {
              value: x.data[i],
              g1: hasComparison ? x.group1_filter[i] : null,
              g2: hasComparison ? x.group2_filter[i] : null
            };
          }
        } else {
          for (var i = 0; i < x.key.length; i++) {
            dataMap[x.key[i]] = {
              value: x.data[i],
              g1: hasComparison ? x.group1_filter[i] : null,
              g2: hasComparison ? x.group2_filter[i] : null
            };
          }
        }

        // Keep a copy of the full dataMap so we can revert if no filters are active
        fullDataMap = dataMap;

        // 4. Initial update
        var initialArrays = buildArrays(fullDataMap);
        updateDisplay(initialArrays.dataArr, initialArrays.g1Arr, initialArrays.g2Arr, settings);

        // 5. Crosstalk group setup
        if (settings.crosstalk_group) {
          ct_filter.setGroup(settings.crosstalk_group);
          // or ct_sel.setGroup(settings.crosstalk_group);
        }

        // 6. Listen for filter events
        ct_filter.on("change", function(e) {
          if (e.value && e.value.length > 0) {
            // Build a subset of dataMap
            var subset = filterByKeys(fullDataMap, e.value);
            var arrays = buildArrays(subset);
            updateDisplay(arrays.dataArr, arrays.g1Arr, arrays.g2Arr, settings);
          } else {
            // No active filter => revert to full
            var allArrays = buildArrays(fullDataMap);
            updateDisplay(allArrays.dataArr, allArrays.g1Arr, allArrays.g2Arr, settings);
          }
        });

        // Similarly, if you also want to listen for selection events:
        // ct_sel.on("change", function(e) { ... })

      },

      resize: function(width, height) {
        // No special resizing logic is needed here
      }
    };
  }
});
