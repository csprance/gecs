# Grafana Dashboard Troubleshooting

## Test Queries for InfluxDB

### 1. Basic Data Check

```flux
from(bucket: "performance")
  |> range(start: -30d)
  |> limit(n: 10)
```

### 2. Check Measurements

```flux
from(bucket: "performance")
  |> range(start: -30d)
  |> group()
  |> distinct(column: "_measurement")
```

### 3. Check Fields

```flux
from(bucket: "performance")
  |> range(start: -30d)
  |> group()
  |> distinct(column: "_field")
```

### 4. Simple Time Series

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
```

### 5. With Specific Test

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test == "entity_creation")
```

### 6. Performance by Test Category

**Entity Operations:**

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test =~ /entity_.*/)
```

**Cache Operations:**

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test =~ /cache_.*/)
```

**Query Performance:**

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test =~ /query_.*/)
```

**System Processing:**

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test =~ /system_.*/)
```

### 7. Scale Comparison for Specific Category

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test =~ /hotpath_.*/)
  |> group(columns: ["scale"])
  |> mean()
  |> sort(columns: ["scale"])
```

### 8. Scale Impact for Key Operations

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test == "entity_creation" or r.test == "component_addition" or r.test == "query_with_all")
  |> group(columns: ["test", "scale"])
  |> mean()
```

### 9. Performance Scaling Analysis

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test == "entity_creation")
  |> group(columns: ["scale"])
  |> mean()
  |> map(fn: (r) => ({ r with scale_factor: if r.scale == 100 then 1.0 else float(v: r._value) / float(v: r._value) }))
```

### 10. Performance Regression Detection

```flux
from(bucket: "performance")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test == "entity_creation")
  |> aggregateWindow(every: 1d, fn: mean)
  |> derivative(unit: 1d, nonNegative: false)
```

### 11. Check Available Scale Values

```flux
from(bucket: "performance")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "scale")
  |> group()
  |> distinct(column: "_value")
  |> sort(columns: ["_value"])
```

### 12. Check Scale Field vs Tag

```flux
from(bucket: "performance")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> group()
  |> distinct(column: "scale")
  |> sort(columns: ["scale"])
```

### 13. Top Slowest Tests (Any Scale)

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> group(columns: ["test"])
  |> mean()
  |> group()
  |> sort(columns: ["_value"], desc: true)
  |> limit(n: 10)
```

## Troubleshooting Steps

1. Go to Grafana → Explore
2. Select the InfluxDB-GECS datasource
3. Try the queries above in order
4. Check what data is returned
5. If no data, check InfluxDB directly or data loader logs

## Common Issues

- Wrong bucket name
- Wrong measurement name
- Data not imported
- Time range issues
- Datasource not configured correctly
