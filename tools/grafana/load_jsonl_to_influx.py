#!/usr/bin/env python3
"""
Load JSONL performance data into InfluxDB for Grafana visualization
"""
import json
import os
import glob
from datetime import datetime
import time

try:
    from influxdb_client import InfluxDBClient, Point
    from influxdb_client.client.write_api import SYNCHRONOUS
except ImportError:
    print("Installing required packages...")
    os.system("pip install influxdb-client")
    from influxdb_client import InfluxDBClient, Point
    from influxdb_client.client.write_api import SYNCHRONOUS

def load_jsonl_files():
    """Load all JSONL files from /data/perf into InfluxDB"""
    
    # InfluxDB configuration from environment
    url = os.getenv('INFLUXDB_URL', 'http://localhost:8086')
    token = os.getenv('INFLUXDB_TOKEN')
    org = os.getenv('INFLUXDB_ORG', 'gecs')
    bucket = os.getenv('INFLUXDB_BUCKET', 'performance')
    
    if not token:
        print("Error: INFLUXDB_TOKEN environment variable not set")
        return
    
    # Wait for InfluxDB to be ready
    print("Waiting for InfluxDB to be ready...")
    for i in range(30):
        try:
            client = InfluxDBClient(url=url, token=token, org=org)
            health = client.health()
            if health.status == "pass":
                print("InfluxDB is ready!")
                break
        except Exception as e:
            print(f"Waiting for InfluxDB... ({i+1}/30)")
            time.sleep(2)
    else:
        print("Failed to connect to InfluxDB after 60 seconds")
        return
    
    write_api = client.write_api(write_options=SYNCHRONOUS)
    
    # Find all JSONL files
    jsonl_files = glob.glob('/data/perf/*.jsonl')
    print(f"Found {len(jsonl_files)} JSONL files")
    
    total_points = 0
    
    for file_path in jsonl_files:
        test_name = os.path.basename(file_path).replace('.jsonl', '')
        print(f"Loading {test_name}...")
        
        points = []
        with open(file_path, 'r') as f:
            for line_num, line in enumerate(f, 1):
                try:
                    data = json.loads(line.strip())
                    
                    # Parse timestamp
                    timestamp = datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00'))
                    
                    # Create InfluxDB point
                    point = Point("gecs_performance") \
                        .tag("test", data['test']) \
                        .tag("godot_version", data['godot_version']) \
                        .field("time_ms", float(data['time_ms'])) \
                        .field("scale", int(data['scale'])) \
                        .time(timestamp)
                    
                    points.append(point)
                    
                except Exception as e:
                    print(f"Error parsing line {line_num} in {file_path}: {e}")
                    continue
        
        if points:
            try:
                write_api.write(bucket=bucket, org=org, record=points)
                total_points += len(points)
                print(f"  Loaded {len(points)} points from {test_name}")
            except Exception as e:
                print(f"Error writing points for {test_name}: {e}")
    
    print(f"\nTotal points loaded: {total_points}")
    client.close()

if __name__ == "__main__":
    load_jsonl_files()