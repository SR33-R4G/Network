#!/usr/bin/env bash
# Features:
# - Choose All tests or custom tests
# - Daily archive file: ~/Desktop/networktest/<LOCATION>_network_test_DDMMYYYY.txt
# - Appends Test Run #N headings, two-line spacing between sections
# - Subtle colored terminal output
# - Auto-detect connection type (Wi-Fi/Ethernet/etc.)
# - SSID & Wi-Fi signal %
# - Ping exact time (last reply) parsing for CSV
# - Speedtest with 1 automatic retry on failure (detect errors incl. 403)
# - CSV summary export: networktest_summary.csv
# - No auto-cleanup

set -u

OUTPUT_DIR=~/Desktop/networktest
mkdir -p "$OUTPUT_DIR"

# Subtle colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Helpers
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
date_str()  { date '+%d%m%Y'; }  # DDMMYYYY format

# Summary vars (defaults)
SUMMARY_PING=""
SUMMARY_PING_TIMES=""
SUMMARY_PING_LAST=""
SUMMARY_DOWNLOAD=""
SUMMARY_UPLOAD=""
SUMMARY_GATEWAY=""
SUMMARY_IP=""
SUMMARY_MAC=""
ACTIVE_IFACE=""
IF_TYPE=""
SSID=""
SIGNAL=""

# ----------------- Functions -----------------
get_active_iface_type() {
    ACTIVE_IFACE=$(nmcli -t -f DEVICE,STATE device 2>/dev/null | awk -F: '$2=="connected" && $1!="lo" {print $1; exit}')
    [[ -z "${ACTIVE_IFACE:-}" ]] && ACTIVE_IFACE=$(ip -o link show up 2>/dev/null | awk -F': ' 'NR==1{print $2}')
    IF_TYPE=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: -v dev="$ACTIVE_IFACE" '$1==dev{print $2}')
    IF_TYPE=${IF_TYPE:-"unknown"}
}

get_wifi_info() {
    SSID="N/A"; SIGNAL="N/A"
    [[ "$IF_TYPE" == "wifi" ]] && {
        wifi_line=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $0; exit}')
        [[ -n "$wifi_line" ]] && {
            SSID=$(echo "$wifi_line" | cut -d: -f2)
            SIGNAL=$(echo "$wifi_line" | cut -d: -f3)
        }
    }
}

get_ip_and_mac() {
    SUMMARY_IP=$(hostname -I 2>/dev/null | xargs)
    if [[ -n "${ACTIVE_IFACE:-}" ]]; then
        SUMMARY_MAC=$(ip link show "$ACTIVE_IFACE" 2>/dev/null | awk '/link\/ether/ {print $2; exit}')
    else
        SUMMARY_MAC="N/A"
    fi
}

get_gateway() {
    SUMMARY_GATEWAY=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')
    SUMMARY_GATEWAY=${SUMMARY_GATEWAY:-"N/A"}
}

do_ping() {
    local target=$1
    # Force C locale and numeric-only output (-n) to stabilize parsing
    out=$(LANG=C ping -n -c 4 "$target" 2>&1)
    echo "$out" | tee -a "$OUTPUT_FILE"

    # Extract each reply's time=XX.xx ms (example: "... time=23.5 ms")
    SUMMARY_PING_TIMES=$(echo "$out" | awk -F'time=' '/bytes from/ {split($2,a," "); print a[1]}' | paste -sd, -)
    SUMMARY_PING_LAST=$(echo "$out" | awk -F'time=' '/bytes from/ {t=$2} END{ if(t!=""){ split(t,a," "); print a[1] } }')

    SUMMARY_PING="$target"
}

do_speedtest() {
    if ! command -v speedtest >/dev/null 2>&1; then
        echo "Speedtest CLI not found." | tee -a "$OUTPUT_FILE"
        SUMMARY_DOWNLOAD="N/A"; SUMMARY_UPLOAD="N/A"; return
    fi
    attempt=1; max_attempts=2
    while (( attempt <= max_attempts )); do
        out=$(speedtest 2>&1); exit_code=$?
        if [[ $exit_code -ne 0 || "$out" =~ ([Ff]orbidden|403|ERROR) ]]; then
            echo "Speedtest attempt $attempt failed." | tee -a "$OUTPUT_FILE"
            ((attempt++))
            if (( attempt <= max_attempts )); then
                echo "Retrying..."
                sleep 1
                continue
            else
                SUMMARY_DOWNLOAD="N/A"; SUMMARY_UPLOAD="N/A"
                return
            fi
        else
            echo "$out" | grep -E "Download|Upload" | tee -a "$OUTPUT_FILE"
            SUMMARY_DOWNLOAD=$(echo "$out" | grep -i "Download" | awk '{for(i=1;i<=NF;i++){if($i ~ /[0-9]+(\.[0-9]+)?/){printf "%s %s", $i, $(i+1); break}}}')
            SUMMARY_UPLOAD=$(echo "$out" | grep -i "Upload" | awk '{for(i=1;i<=NF;i++){if($i ~ /[0-9]+(\.[0-9]+)?/){printf "%s %s", $i, $(i+1); break}}}')
            return
        fi
    done
}

# CSV summary
CSV_FILE="$OUTPUT_DIR/networktest_summary.csv"
[[ ! -f "$CSV_FILE" ]] && echo "Date,TestRun,Location,Interface,Type,IP,Gateway,Ping_ms,Download,Upload,SSID,Signal" > "$CSV_FILE"

# ----------------- Start -----------------
read -p "Enter your location: " LOCATION
DATESTR=$(date_str)
OUTPUT_FILE="$OUTPUT_DIR/${LOCATION}_network_test_$DATESTR.txt"

if [[ -f "$OUTPUT_FILE" ]]; then
    LAST_RUN=$(grep -oP 'Test Run #\K[0-9]+' "$OUTPUT_FILE" 2>/dev/null | tail -1 || echo "")
else
    LAST_RUN=""
fi
TEST_RUN=$(( ${LAST_RUN:-0} + 1 ))

START_TIME=$(timestamp)
echo -e "\n\n\n===================================================" >> "$OUTPUT_FILE"
echo "Test Run #$TEST_RUN - $START_TIME" | tee -a "$OUTPUT_FILE"
echo "===================================================\n" | tee -a "$OUTPUT_FILE"

# ----------------- Pre-selection -----------------
echo -e "${CYAN}Do you want to run all tests or select specific tests?${RESET}"
echo "1) Run All tests"
echo "2) Select tests manually"
read -p "Enter choice (1 or 2): " RUN_MODE

if [[ "$RUN_MODE" == "1" ]]; then
    TEST_LIST=("IP_MAC" "GATEWAY" "PING" "SPEEDTEST")
else
    echo -e "${CYAN}Select which tests to run (comma-separated numbers):${RESET}"
    echo "1) IP & MAC"
    echo "2) Default Gateway"
    echo "3) Ping Test"
    echo "4) Speedtest"
    read -p "Enter your choice(s) e.g., 1,3 : " MANUAL_CHOICES
    TEST_LIST=()
    IFS=',' read -ra CHOICES <<< "$MANUAL_CHOICES"
    for c in "${CHOICES[@]}"; do
        case "$c" in
            1) TEST_LIST+=("IP_MAC") ;;
            2) TEST_LIST+=("GATEWAY") ;;
            3) TEST_LIST+=("PING") ;;
            4) TEST_LIST+=("SPEEDTEST") ;;
        esac
    done
fi

# ----------------- Run Selected Tests -----------------
for TEST in "${TEST_LIST[@]}"; do
    case "$TEST" in
        "IP_MAC")
            TSTAMP=$(timestamp); get_active_iface_type; get_ip_and_mac; get_wifi_info
            echo -e "${YELLOW}[$TSTAMP] == IP & MAC ==${RESET}" | tee -a "$OUTPUT_FILE"
            echo "IP Addresses: $SUMMARY_IP" | tee -a "$OUTPUT_FILE"
            echo "MAC Address: ${SUMMARY_MAC:-N/A}" | tee -a "$OUTPUT_FILE"
            echo "Active Interface: ${ACTIVE_IFACE:-N/A} (${IF_TYPE:-unknown})" | tee -a "$OUTPUT_FILE"
            [[ "$IF_TYPE" == "wifi" ]] && echo "SSID: ${SSID:-N/A} | Signal: ${SIGNAL:-N/A}%" | tee -a "$OUTPUT_FILE"
            echo -e "\n\n" | tee -a "$OUTPUT_FILE"
            ;;
        "GATEWAY")
            get_gateway; TSTAMP=$(timestamp)
            echo -e "${YELLOW}[$TSTAMP] == Default Gateway ==${RESET}" | tee -a "$OUTPUT_FILE"
            echo "Default Gateway: $SUMMARY_GATEWAY" | tee -a "$OUTPUT_FILE"
            echo -e "\n\n" | tee -a "$OUTPUT_FILE"
            ;;
        "PING")
            get_gateway
            echo "Ping target options:"
            echo "1) Default Gateway ($SUMMARY_GATEWAY)"
            echo "2) Specific IP"
            read -p "Choose (1 or 2): " PING_CHOICE
            if [[ "$PING_CHOICE" == "1" ]]; then
                TARGET="$SUMMARY_GATEWAY"
            else
                read -p "Enter IP: " TARGET
            fi
            TSTAMP=$(timestamp)
            echo -e "${YELLOW}[$TSTAMP] == Ping Test ($TARGET) ==${RESET}" | tee -a "$OUTPUT_FILE"
            do_ping "$TARGET"
            if [[ -n "${SUMMARY_PING_TIMES:-}" ]]; then
                echo "Ping times (ms): ${SUMMARY_PING_TIMES}" | tee -a "$OUTPUT_FILE"
            fi
            if [[ -n "${SUMMARY_PING_LAST:-}" ]]; then
                echo "Exact ping (last reply): ${SUMMARY_PING_LAST} ms" | tee -a "$OUTPUT_FILE"
            fi
            echo -e "\n\n" | tee -a "$OUTPUT_FILE"
            ;;
        "SPEEDTEST")
            TSTAMP=$(timestamp)
            echo -e "${YELLOW}[$TSTAMP] == Speedtest ==${RESET}" | tee -a "$OUTPUT_FILE"
            do_speedtest
            echo -e "\n\n" | tee -a "$OUTPUT_FILE"
            ;;
    esac
done

# ----------------- Final Summary -----------------
END_TIME=$(timestamp)
get_active_iface_type; get_ip_and_mac; get_gateway; get_wifi_info
echo -e "${CYAN}\n================== Final Summary ==================${RESET}" | tee -a "$OUTPUT_FILE"
echo "Location: $LOCATION" | tee -a "$OUTPUT_FILE"
echo "Test Run #: $TEST_RUN" | tee -a "$OUTPUT_FILE"
echo "Start Time: $START_TIME" | tee -a "$OUTPUT_FILE"
echo "End Time: $END_TIME" | tee -a "$OUTPUT_FILE"
echo "Active Interface: ${ACTIVE_IFACE:-N/A} (${IF_TYPE:-unknown})" | tee -a "$OUTPUT_FILE"
echo "IP Addresses: ${SUMMARY_IP:-N/A}" | tee -a "$OUTPUT_FILE"
echo "MAC Address: ${SUMMARY_MAC:-N/A}" | tee -a "$OUTPUT_FILE"
echo "Default Gateway: ${SUMMARY_GATEWAY:-N/A}" | tee -a "$OUTPUT_FILE"
[[ -n "${SUMMARY_PING:-}" ]] && echo "Last Ping Target: ${SUMMARY_PING}" | tee -a "$OUTPUT_FILE"
[[ -n "${SUMMARY_PING_LAST:-}" ]] && echo "Exact Ping (ms): ${SUMMARY_PING_LAST}" | tee -a "$OUTPUT_FILE"
echo "Last Speedtest:" | tee -a "$OUTPUT_FILE"
echo "Download: ${SUMMARY_DOWNLOAD:-N/A}" | tee -a "$OUTPUT_FILE"
echo "Upload: ${SUMMARY_UPLOAD:-N/A}" | tee -a "$OUTPUT_FILE"
[[ "$IF_TYPE" == "wifi" ]] && echo "SSID: ${SSID:-N/A} | Signal: ${SIGNAL:-N/A}%" | tee -a "$OUTPUT_FILE"
echo -e "===================================================\n\n\n" | tee -a "$OUTPUT_FILE"

# ----------------- Append CSV summary -----------------
csv_ping="${SUMMARY_PING_LAST:-N/A}"
echo "$(date '+%d-%m-%Y'),$TEST_RUN,$LOCATION,${ACTIVE_IFACE:-N/A},${IF_TYPE:-unknown},\"${SUMMARY_IP:-N/A}\",${SUMMARY_GATEWAY:-N/A},${csv_ping},\"${SUMMARY_DOWNLOAD:-N/A}\",\"${SUMMARY_UPLOAD:-N/A}\",\"${SSID:-N/A}\",\"${SIGNAL:-N/A}\"" >> "$CSV_FILE"

echo -e "${GREEN}Report saved to:${RESET} $OUTPUT_FILE"
echo -e "${CYAN}CSV summary updated:${RESET} $CSV_FILE"
