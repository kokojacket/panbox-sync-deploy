#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

export PANBOX_SYNC_TEST_MODE=1
export INSTALL_DIR="$test_root/install"
mkdir -p "$INSTALL_DIR"
touch "$INSTALL_DIR/docker-compose.yml"

source "$repo_dir/panbox-sync.sh"

events="$test_root/events"
require_docker_runtime() { :; }
detect_docker_gid() { DOCKER_GID=999; }
create_env_file() { :; }
download_latest_compose_config() { echo download >> "$events"; }
stop_compose_services() { echo stop >> "$events"; }
ensure_data_directories() { :; }
migrate_openlist_data_dir() { :; }
docker() { echo "$1" >> "$events"; }
run_compose() { echo "compose $*" >> "$events"; }
show_access_info() { :; }
print_header() { :; }
print_info() { :; }
print_success() { :; }
print_error() { :; }

update_panbox

cat > "$test_root/expected" <<'EOF'
download
stop
pull
compose up -d --force-recreate
EOF

diff -u "$test_root/expected" "$events"
