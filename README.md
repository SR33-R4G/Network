# 🛰️ NetworkTest – Bash-based Network Diagnostics Tool

**NetworkTest** is a simple yet powerful Bash script for Linux that performs detailed network diagnostics and saves the results locally.  
It’s ideal for **network engineers, field technicians, and sysadmins** who want quick, repeatable testing with automatic log files and CSV summaries.

---

## 🚀 Features

- 🔹 **Interactive Mode** — Run all tests or select specific ones  
- 🗓️ **Daily Log Files** — Automatically stored in:  
  `~/Desktop/networktest/<LOCATION>_network_test_DDMMYYYY.txt`
- 🧾 **CSV Summary Report** — Cumulative log file:  
  `~/Desktop/networktest/networktest_summary.csv`
- 🧠 **Auto-Detection:**
  - Active interface (Wi-Fi, Ethernet, etc.)
  - SSID & Wi-Fi signal strength
- 📡 **Network Tests:**
  - IP & MAC address detection
  - Default Gateway lookup
  - Ping test — saves **exact ping time (last reply)** in ms
  - Speedtest with automatic retry
- 🎨 **Colored Terminal Output** for better readability
- 📊 **Appends “Test Run #”** with timestamps for every run
- 💾 Keeps all historical logs (no auto-cleanup)

---

## 🧰 Requirements

| Dependency | Purpose | Install (Debian/Ubuntu) |
|-------------|----------|-------------------------|
| `bash` | Shell interpreter | *(default)* |
| `nmcli` | NetworkManager CLI | `sudo apt install network-manager` |
| `ping` | Network reachability test | *(default)* |
| `speedtest` | Speedtest CLI by Ookla | `sudo apt install speedtest-cli` *(or Ookla’s official binary)* |
| `awk`, `grep`, `sed` | Text parsing tools | *(default)* |

---

## ⚙️ Installation

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/networktest.git
cd networktest

# 2. Make it executable
chmod +x networktest

# 3. Run the script
./networktest
