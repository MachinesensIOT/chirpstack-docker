#!/usr/bin/env bash
# =============================================================================
# validate.sh — Smoke-test script for the ChirpStack + InfluxDB + Grafana stack
#
# Usage:
#   Run AFTER starting the stack with:  docker compose up -d
#   Then execute:                        bash scripts/validate.sh
#
# The script sources .env from the repo root if the required environment
# variables are not already set. It performs four checks and exits with
# code 0 if all pass, or 1 if any fail.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}[PASS]${RESET} $1"; }
fail() { echo -e "  ${RED}[FAIL]${RESET} $1"; }

# ---------------------------------------------------------------------------
# Source .env from repo root if required variables are not already set
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ -z "${INFLUXDB_ADMIN_TOKEN:-}" || -z "${GF_SECURITY_ADMIN_USER:-}" || -z "${GF_SECURITY_ADMIN_PASSWORD:-}" ]]; then
  if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck source=/dev/null
    set -a
    source "${ENV_FILE}"
    set +a
  else
    echo -e "${RED}ERROR:${RESET} .env file not found at ${ENV_FILE} and required environment variables are not set."
    echo "       Copy .env.example to .env and fill in the values, then re-run."
    exit 1
  fi
fi

# Validate that required variables are now available
MISSING=()
[[ -z "${INFLUXDB_ADMIN_TOKEN:-}" ]]       && MISSING+=("INFLUXDB_ADMIN_TOKEN")
[[ -z "${GF_SECURITY_ADMIN_USER:-}" ]]     && MISSING+=("GF_SECURITY_ADMIN_USER")
[[ -z "${GF_SECURITY_ADMIN_PASSWORD:-}" ]] && MISSING+=("GF_SECURITY_ADMIN_PASSWORD")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo -e "${RED}ERROR:${RESET} The following required variables are not set:"
  for v in "${MISSING[@]}"; do
    echo "         - ${v}"
  done
  exit 1
fi

# ---------------------------------------------------------------------------
# Configuration (override via environment if needed)
# ---------------------------------------------------------------------------
INFLUXDB_URL="${INFLUXDB_URL:-http://localhost:8086}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
INFLUXDB_BUCKET="${INFLUXDB_BUCKET:-chirpstack}"

# ---------------------------------------------------------------------------
# Run checks
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}ChirpStack Stack Validation${RESET}"
echo "============================================"

FAILURES=0

# --- Check 1: InfluxDB health ---
echo ""
echo -e "${BOLD}1. InfluxDB health${RESET}  (${INFLUXDB_URL}/health)"
INFLUX_HEALTH=$(curl -sf "${INFLUXDB_URL}/health" 2>/dev/null || true)
if echo "${INFLUX_HEALTH}" | grep -q '"status":"pass"'; then
  pass "InfluxDB is healthy"
else
  fail "InfluxDB health check failed (response: ${INFLUX_HEALTH:-<no response>})"
  FAILURES=$((FAILURES + 1))
fi

# --- Check 2: InfluxDB bucket exists ---
echo ""
echo -e "${BOLD}2. InfluxDB bucket '${INFLUXDB_BUCKET}' exists${RESET}"
BUCKET_RESPONSE=$(curl -sf \
  -H "Authorization: Token ${INFLUXDB_ADMIN_TOKEN}" \
  "${INFLUXDB_URL}/api/v2/buckets?name=${INFLUXDB_BUCKET}" 2>/dev/null || true)
if echo "${BUCKET_RESPONSE}" | grep -q "\"name\":\"${INFLUXDB_BUCKET}\""; then
  pass "Bucket '${INFLUXDB_BUCKET}' exists in InfluxDB"
else
  fail "Bucket '${INFLUXDB_BUCKET}' not found in InfluxDB (response: ${BUCKET_RESPONSE:-<no response>})"
  FAILURES=$((FAILURES + 1))
fi

# --- Check 3: Grafana health ---
echo ""
echo -e "${BOLD}3. Grafana health${RESET}  (${GRAFANA_URL}/api/health)"
GRAFANA_HEALTH=$(curl -sf "${GRAFANA_URL}/api/health" 2>/dev/null || true)
if echo "${GRAFANA_HEALTH}" | grep -q '"database":"ok"'; then
  pass "Grafana is healthy"
else
  fail "Grafana health check failed (response: ${GRAFANA_HEALTH:-<no response>})"
  FAILURES=$((FAILURES + 1))
fi

# --- Check 4: Grafana InfluxDB datasource is configured ---
echo ""
echo -e "${BOLD}4. Grafana InfluxDB datasource${RESET}"
DATASOURCES=$(curl -sf \
  -u "${GF_SECURITY_ADMIN_USER}:${GF_SECURITY_ADMIN_PASSWORD}" \
  "${GRAFANA_URL}/api/datasources" 2>/dev/null || true)
if echo "${DATASOURCES}" | grep -qi '"type":"influxdb"'; then
  pass "InfluxDB datasource is configured in Grafana"
else
  fail "No InfluxDB datasource found in Grafana (response: ${DATASOURCES:-<no response>})"
  FAILURES=$((FAILURES + 1))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
if [[ ${FAILURES} -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All checks passed.${RESET} The stack is ready."
  echo ""
  exit 0
else
  echo -e "${RED}${BOLD}${FAILURES} check(s) failed.${RESET} Review the output above."
  echo ""
  echo "Tips:"
  echo "  - Ensure the stack is running:  docker compose up -d"
  echo "  - Wait a few seconds for services to initialise, then re-run this script."
  echo "  - Check service logs:           docker compose logs influxdb grafana"
  exit 1
fi
