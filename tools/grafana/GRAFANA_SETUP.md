# GECS Performance Monitoring with Grafana

This setup provides a complete monitoring solution for GECS performance data using Grafana, InfluxDB, and Docker Compose.

## File Structure

```
tools/grafana/
├── docker-compose.yml          # Complete stack definition
├── load_jsonl_to_influx.py     # Data loader script
└── provisioning/               # Grafana auto-configuration
    ├── datasources/
    │   └── influxdb.yml        # InfluxDB connection
    └── dashboards/
        ├── dashboard.yml       # Dashboard provider config
        └── gecs-performance.json # Main performance dashboard
```

## Quick Start

1. **Navigate to the Grafana directory:**

   ```bash
   cd tools/grafana
   ```

2. **Start the monitoring stack:**

   ```bash
   docker-compose up -d
   ```

3. **Access Grafana:**

   - URL: http://localhost:3000
   - Username: `admin`
   - Password: `admin`

4. **View the dashboard:**
   - Navigate to "GECS Performance" folder
   - Open "GECS Performance Dashboard"

## VS Code Integration

The setup includes VS Code tasks for easy management (all run in background):

### Tasks (Ctrl+Shift+P → "Run Task")

**Docker Operations:**

- **Grafana: Start Monitoring Stack** - Starts the entire stack
- **Grafana: Stop Monitoring Stack** - Stops all services
- **Grafana: Restart Data Loader** - Reloads JSONL data
- **Grafana: View Logs** - Shows real-time logs (background task)

**Utilities:**

- **Grafana: Open Dashboard** - Opens Grafana in browser
- **Grafana: Reload JSONL Data** - Manual data reload

### Quick Access

1. **Start monitoring**: `Ctrl+Shift+P` → "Run Task" → "Grafana: Start Monitoring Stack"
2. **Open dashboard**: `Ctrl+Shift+P` → "Run Task" → "Grafana: Open Dashboard"
3. **View logs**: `Ctrl+Shift+P` → "Run Task" → "Grafana: View Logs"

## What's Included

### Services

- **InfluxDB 2.7**: Time-series database for storing performance metrics
- **Grafana**: Visualization and dashboarding platform
- **Data Loader**: Python service that imports JSONL files into InfluxDB

### Dashboard Features

- **Performance Overview**: All tests with time-series visualization
- **Performance by Scale**: Bar chart showing average performance by scale
- **Hotpath Performance**: Focused view on critical performance paths
- **System Performance**: System-specific metrics
- **Cache Performance**: Cache hit/miss and invalidation metrics

## Data Structure

Your JSONL files are automatically imported with the following structure:

- **Measurement**: `gecs_performance`
- **Tags**: `test`, `godot_version`
- **Fields**: `time_ms`, `scale`
- **Timestamp**: From the `timestamp` field in your JSONL

## Adding New Data

The data loader runs once on startup. To reload data:

1. **Update JSONL files** in `reports/perf/`
2. **Restart the data loader:**
   ```bash
   cd tools/grafana
   docker-compose restart data-loader
   ```

Or run manually:

```bash
cd tools/grafana
docker-compose run --rm data-loader python load_jsonl_to_influx.py
```

## Custom Queries

Use Flux query language in Grafana. Example queries:

### Get latest performance for a specific test:

```flux
from(bucket: "performance")
  |> range(start: -1d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> filter(fn: (r) => r.test == "entity_creation")
  |> last()
```

### Compare performance across scales:

```flux
from(bucket: "performance")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> group(columns: ["scale"])
  |> mean()
```

### Performance regression detection:

```flux
from(bucket: "performance")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "gecs_performance")
  |> filter(fn: (r) => r._field == "time_ms")
  |> aggregateWindow(every: 1d, fn: mean)
  |> derivative(unit: 1d, nonNegative: false)
```

## Configuration

### InfluxDB Access

- **URL**: http://localhost:8086
- **Organization**: `gecs`
- **Bucket**: `performance`
- **Token**: `gecs-performance-token-12345`

### Data Persistence

- InfluxDB data: `influxdb-data` volume
- Grafana data: `grafana-data` volume

## Troubleshooting

### Data not appearing?

1. Check data loader logs: `docker-compose logs data-loader`
2. Verify JSONL files exist: `ls -la reports/perf/`
3. Check InfluxDB connection: `docker-compose logs influxdb`

### Connection issues?

1. Ensure ports aren't in use: `netstat -an | grep -E "3000|8086"`
2. Check Docker networks: `docker network ls`
3. Restart services: `docker-compose restart`

## Alternative Tools

If you prefer other tools:

### 1. **Prometheus + Grafana**

- Convert JSONL to Prometheus metrics format
- Better for real-time monitoring
- More complex setup for historical data

### 2. **Elastic Stack (ELK)**

- Elasticsearch + Kibana
- Better for log analysis and search
- Heavier resource usage

### 3. **TimescaleDB + Grafana**

- PostgreSQL-based time-series
- SQL queries instead of Flux
- Better for complex relational queries

## Troubleshooting

### Dashboard Panels Are Blank

If you can see the dashboard but panels show no data:

1. **Check data was imported:**

   ```bash
   cd tools/grafana
   docker-compose logs data-loader
   ```

2. **Test queries in Grafana Explore:**

   - Go to Grafana → Explore (compass icon)
   - Select "InfluxDB-GECS" datasource
   - Try this basic query:

   ```flux
   from(bucket: "performance")
     |> range(start: -30d)
     |> limit(n: 10)
   ```

3. **Check specific data exists:**

   ```flux
   from(bucket: "performance")
     |> range(start: -30d)
     |> filter(fn: (r) => r._measurement == "gecs_performance")
     |> filter(fn: (r) => r._field == "time_ms")
     |> limit(n: 10)
   ```

4. **Restart data loader if needed:**

   ```bash
   cd tools/grafana
   docker-compose restart data-loader
   ```

5. **Try the simpler dashboard:** "GECS Performance - Simple" has basic queries

### Data not appearing?

1. Check data loader logs: `docker-compose logs data-loader`
2. Verify JSONL files exist: `ls -la ../../reports/perf/`
3. Check InfluxDB connection: `docker-compose logs influxdb`

### Connection issues?

1. Ensure ports aren't in use: `netstat -an | grep -E "3000|8086"`
2. Check Docker networks: `docker network ls`
3. Restart services: `docker-compose restart`

## Performance Tips

1. **Batch data loading**: The loader processes all files at once for efficiency
2. **Data retention**: Configure InfluxDB retention policies for large datasets
3. **Query optimization**: Use appropriate time ranges and aggregations
4. **Index optimization**: InfluxDB automatically indexes tags

## Extending the Setup

### Adding Alerts

1. Configure Grafana alerting rules
2. Set up notification channels (email, Slack, etc.)
3. Define thresholds for performance regressions

### Adding More Dashboards

1. Create new JSON files in `grafana/provisioning/dashboards/`
2. Use existing dashboard as template
3. Restart Grafana or wait for auto-reload

### Custom Data Sources

1. Modify `load_jsonl_to_influx.py` for different data formats
2. Add new measurement types or fields
3. Update dashboard queries accordingly
