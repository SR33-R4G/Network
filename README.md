# 🛰️ NetworkTest – Bash-based Network Diagnostics Tool

**NetworkTest** is a simple yet powerful Bash script for Linux that performs detailed network diagnostics and saves the results locally.
It’s ideal for network engineers, field technicians, and sysadmins who want quick, repeatable testing with automatic log files and CSV summaries.

## 🚀 Features

- Interactive Mode — Run all tests or select specific ones
- Daily Log Files — Stored in `~/Desktop/networktest/<LOCATION>_network_test_DDMMYYYY.txt`
- CSV Summary Report — `~/Desktop/networktest/networktest_summary.csv`
- Auto-detects active interface, SSID & Wi-Fi signal strength
- Tests: IP/MAC, Gateway, Ping (exact ms), Speedtest (auto retry)
- Colored terminal output and persistent logs

## ⚙️ Installation

```bash
git clone https://github.com/<your-username>/networktest.git
cd networktest
chmod +x networktest
./networktest
```

## 📸 Screenshots

| Description | Screenshot |
|--------------|-------------|
| **Running networktest in terminal** | ![Terminal Output](Network/sample_output.png) |
| **structure of file system** | ![Terminal Output](Network/structure.png) |


## 🏷️ Author

**Sreerag M S**
Network Admin | Field Technician | Linux Enthusiast
