#!/bin/bash

GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"
GRAFANA_URL="http://localhost:3000"

extract_datasources() {
  local file="$1"

  jq '.. | .datasource? // empty | select (.type != "grafana") | .type ' "$file" | sort | uniq | cut -d'"' -f2
}

get_datasource_uid() {
  local datasource_type="$1"

  curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/datasources" | \
  jq -r '.[] | select(.type == "'"$datasource_type"'" and .url != "") | .uid' | head -n1
}

send_dashboard_to_grafana() {
  tmp_json_file="$1"

  curl -X POST \
    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
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
  done

  send_dashboard_to_grafana $tmp_json_file
  rm "$tmp_json_file"
}

if [ -d "$1" ]; then
  find "$1" -maxdepth 1 -name "*.json" -print0 | while IFS= read -r -d $'\0' file; do
    import_dashboard "$file"
    echo -e "\n$file\n"
  done
else
  import_dashboard "$1"
  echo -e "\n$1\n"
fi

