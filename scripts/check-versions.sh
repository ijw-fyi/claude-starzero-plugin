#!/bin/sh
# Fails when plugin.json and marketplace.json disagree on the plugin version or description.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)

json_field() {
  # json_field <file> <key> [marker]: first string value for the key, after the marker line when
  # one is given (the manifests are flat enough; the marker skips the marketplace's own fields)
  sed -n "/${3:-^}/,\$p" "$1" | sed -n "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

plugin_version=$(json_field "$root/.claude-plugin/plugin.json" version)
marketplace_version=$(json_field "$root/.claude-plugin/marketplace.json" version '"plugins"')
cli_version=$(tr -d '[:space:]' < "$root/reference/CLI_VERSION")

if [ "$plugin_version" != "$marketplace_version" ]; then
  printf 'plugin.json is %s but marketplace.json is %s\n' "$plugin_version" "$marketplace_version" >&2
  exit 1
fi
plugin_description=$(json_field "$root/.claude-plugin/plugin.json" description)
marketplace_description=$(json_field "$root/.claude-plugin/marketplace.json" description '"plugins"')
if [ "$plugin_description" != "$marketplace_description" ]; then
  printf 'plugin.json and marketplace.json describe the plugin differently\n' >&2
  exit 1
fi
printf 'versions agree: plugin %s, cli %s; descriptions agree\n' "$plugin_version" "$cli_version"
