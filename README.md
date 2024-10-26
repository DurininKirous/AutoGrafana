# AutoGrafana
Script for automatic deployment of dashboards in Grafana

For proper operation, it is assumed that the necessary datasources for dashboards are already installed on Grafana

Usage: ./grafana.sh [-u username] [-p password] [-k api_key] [-g grafana_url] file.json_or_directory
# Default configuration
GRAFANA_USER="admin"

GRAFANA_PASSWORD="admin"

GRAFANA_URL="http://localhost:3000"

API_KEY=""
