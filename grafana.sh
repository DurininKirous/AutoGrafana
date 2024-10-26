#!/bin/bash

# Default configuration
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"
GRAFANA_URL="http://localhost:3000"
API_KEY=""

# Function to display usage
usage() {
  echo "Usage: $0 [-u username] [-p password] [-k api_key] [-g grafana_url] file_or_directory"
  exit 1
}

extract_datasources() {
  local file="$1"
  jq '.. | .datasource? // empty | select (.type != "grafana") | .type ' "$file" | sort | uniq | cut -d'"' -f2
}

get_datasource_uid() {
  local datasource_type="$1"
  local auth_option=""

  # Use API key if provided
  if [ -n "$API_KEY" ]; then
    auth_option="-H 'Authorization: Bearer $API_KEY'"
  else
    auth_option="-u $GRAFANA_USER:$GRAFANA_PASSWORD"
  fi

  curl -s $auth_option "$GRAFANA_URL/api/datasources" | \
  jq -r '.[] | select(.type == "'"$datasource_type"'" and .url != "") | .uid' | head -n1
}

send_dashboard_to_grafana() {
  local tmp_json_file="$1"
  local auth_option=""

  # Use API key if provided
  if [ -n "$API_KEY" ]; then
    auth_option="-H 'Authorization: Bearer $API_KEY'"
  else
    auth_option="-u $GRAFANA_USER:$GRAFANA_PASSWORD"
  fi

  curl -s -X POST \
    $auth_option \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d @"$tmp_json_file" \
    "$GRAFANA_URL/api/dashboards/db"
}

import_dashboard() {
  local file="$1"
  local tmp_json_file=$(mktemp)
  declare -A datasource_uids

  while read -r type; do
    datasource_uids["$type"]=$(get_datasource_uid "$type")
  done < <(extract_datasources "$file")

  sed 's/\( *"annotations"\)/ "dashboard": {\n \1/;
       s/ *"weekStart": *".*"/&\n },\n "overwrite": true/' "$file" > "$tmp_json_file"

  for type in "${!datasource_uids[@]}"; do
    uid=${datasource_uids[$type]}
    sed -i "/\"type\": *\"$type\"/{n;s/\(\"uid\": *\"\).*\(\".*\)/\1$uid\2/}" "$tmp_json_file"
	sed -i "s/"id": .*,/"id": null,/g" "$tmp_json_file"
  done

  send_dashboard_to_grafana "$tmp_json_file"
  rm "$tmp_json_file"
}

# Check if something is provided
if [ -z "$1" ]; then
  usage
  exit 1
fi

# Parse command line options
while getopts ":u:p:k:g:" opt; do
  case $opt in
    u) GRAFANA_USER="$OPTARG" ;;
    p) GRAFANA_PASSWORD="$OPTARG" ;;
    k) API_KEY="$OPTARG" ;;
    g) GRAFANA_URL="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND -1))

if [ -d "$1" ]; then
  find "$1" -maxdepth 1 -name "*.json" -print0 | while IFS= read -r -d '' file; do
    import_dashboard "$file"
    echo -e "\nImported: $file\n"
  done
else
  import_dashboard "$1"
  echo -e "\nImported: $1\n"
fi

