#!/usr/bin/env bash
# Build the place file: Rojo -> data tests -> bake the map into Workspace
# Requires rojo (7.4+) and lune (0.8+) on PATH (install with rokit)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
rojo build default.project.json -o build/GrandVoyage.rbxlx
lune run tools/test.luau build/GrandVoyage.rbxlx
lune run tools/bake.luau build/GrandVoyage.rbxlx build/GrandVoyage.rbxl
echo "✅ build/GrandVoyage.rbxl (map baked in) is ready to open in Roblox Studio"
