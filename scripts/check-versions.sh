#!/bin/sh
# Fails when plugin.json and marketplace.json disagree on the plugin version.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)

json_field() {
  # json_field <file> <key>: first string value for the key (the manifests are flat enough)
  sed -n "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -n 1
}

plugin_version=$(json_field "$root/.claude-plugin/plugin.json" version)
marketplace_version=$(json_field "$root/.claude-plugin/marketplace.json" version)
cli_version=$(tr -d '[:space:]' < "$root/reference/CLI_VERSION")

if [ "$plugin_version" != "$marketplace_version" ]; then
  printf 'plugin.json is %s but marketplace.json is %s\n' "$plugin_version" "$marketplace_version" >&2
  exit 1
fi
printf 'versions agree: plugin %s, cli %s\n' "$plugin_version" "$cli_version"
