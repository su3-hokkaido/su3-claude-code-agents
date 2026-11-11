#!/bin/sh
# Build a throwaway stub plugin for loop tests (plan task 3b.0, test scenarios L01 to L13).
# Usage: sh test/stub-plugin/build.sh <out-dir>
# The output is a plugin named su3-developer-set (the loop skills dispatch that name) holding
# the REAL skills of plugins/su3-developer-set and STUB agents that return fixed hand-backs
# read from <project>/.stub/<role>.txt. Run it with: claude --plugin-dir <out-dir> -p "..."
# Never commit <out-dir>. It must not sit under plugins/.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out=${1:?usage: build.sh <out-dir>}
case "$out" in "$repo"/plugins/*) echo "build.sh: out-dir must not be under plugins/" >&2; exit 2 ;; esac
[ -e "$out" ] && { echo "build.sh: $out exists; choose a new directory" >&2; exit 2; }
src="$repo/plugins/su3-developer-set"
mkdir -p "$out/.claude-plugin" "$out/agents"
cp -R "$src/skills" "$out/skills"
cp "$src/.claude-plugin/plugin.json" "$out/.claude-plugin/plugin.json"
for role in project-manager qa qc app-developer system-architect sre aire; do
  sed "s/@ROLE@/$role/g" "$here/stub-agent.template.md" > "$out/agents/su3-$role.md"
done
echo "stub plugin written to $out"
