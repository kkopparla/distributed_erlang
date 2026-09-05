# Distributed Erlang Bitcoin Miner (COP5615 Project 1)

A high-performance distributed SHA-256 Bitcoin mining system written in **Erlang** using exclusively the **Actor Model**.

Designed for multi-core parallelism and cross-machine distributed execution across two systems connected to the same Wi-Fi network.

---

## 1. System Overview & Architecture

### Actor Hierarchy & Message Flow

```
+-------------------------------------------------------------------------+
|                              SERVER NODE                                |
|                        (server@192.168.0.152)                           |
|                                                                         |
|   +-----------------------------------------------------------------+   |
|   |                           Boss Actor                            |   |
|   | - Holds state: K, Prefix, CurrentIndex, BatchSize               |   |
|   | - Manages problem range assignment                              |   |
|   | - Formats and prints all found coins to standard output         |   |
|   +-----------------------------------------------------------------+   |
|            ^                        ^                      ^            |
|            | {get_work, self()}     | {get_work, self()}   |            |
|            | {coin_found, ...}      | {coin_found, ...}    | (Erlang    |
|            v                        v                      |  Network   |
|     +--------------+         +--------------+              |  Messaging)|
|     | Local Worker | ...     | Local Worker |              |            |
|     |   Actor 1    |         |   Actor N    |              |            |
|     +--------------+         +--------------+              |            |
+------------------------------------------------------------|------------+
                                                             |
                                           Distributed Wi-Fi |
                                           (Port 4369, EPMD) |
                                                             v
+-------------------------------------------------------------------------+
|                              WORKER NODE                                |
|                         (worker@192.168.0.26)                           |
|                                                                         |
|   +-----------------------------------------------------------------+   |
|   |                       Worker Coordinator                        |   |
|   | - Auto-discovers CPU cores via erlang:system_info               |   |
|   | - Spawns M remote worker actors                                 |   |
|   +-----------------------------------------------------------------+   |
|            |                                        |                   |
|            v                                        v                   |
|     +---------------+                        +---------------+          |
|     | Remote Worker |         ...            | Remote Worker |          |
|     |    Actor 1    |                        |    Actor M    |          |
|     +---------------+                        +---------------+          |
|     (Mines batches silently and streams found coins directly to Boss)   |
|     (Does not print coins locally - Server prints all results)          |
+-------------------------------------------------------------------------+
```

### Actor Model Specifications
- **Pure Actor Model**: All concurrency and parallelism uses Erlang process primitives (`spawn`, `!`, `receive`). No shared memory or mutexes.
- **Boss Actor (`boss.erl`)**:
  - Assigns work ranges (`StartIndex` to `StartIndex + BatchSize - 1`) dynamically when actors send `{get_work, WorkerPid}`.
  - Automatically accommodates new remote worker nodes as soon as they join.
  - Formats output strictly according to assignment requirements:
    ```
    <input_string>\t<sha256_hash>
    ```
- **Worker Actors (`worker.erl`)**:
  - Spawns worker actors matching the number of CPU cores (`erlang:system_info(schedulers_online)`).
  - Evaluates SHA-256 hashes using binary pattern matching for maximal speed (~1.2M+ hashes/sec per core).
  - Sends discovered coins `{coin_found, InputStr, HexHash}` directly to the Boss actor.
  - Stays completely silent on worker machines as required.

---

## 2. Quick Start

### Prerequisites
- **Erlang/OTP**: Erlang 17+ installed on both machines and added to `PATH`.
  - Windows: Check via `erl -version`.
  - If Erlang is not installed on Machine 2, download the official installer from [erlang.org](https://www.erlang.org/downloads) or run `winget install Erlang.Erlang` in PowerShell.

---

### Running Distributed Between Two Machines on Wi-Fi

#### Machine 1: Server (`192.168.0.152`)
Open PowerShell or Command Prompt in this project directory:
```powershell
.\project1.ps1 4
```
*(Or in Command Prompt: `project1 4`)*

This starts the server with:
- Target: 4 leading zeroes
- Automatically binds to Wi-Fi IP `192.168.0.152` as `server@192.168.0.152`
- Mines immediately with local CPU worker actors
- Listens for remote worker connections

#### Machine 2: Worker (`192.168.0.26`)
Copy this folder (or git clone) to Machine 2. Open PowerShell or Command Prompt:
```powershell
.\project1.ps1 192.168.0.152
```
*(Or in Command Prompt: `project1 192.168.0.152`)*

This starts the worker:
- Automatically detects Machine 2's IP (`192.168.0.26`)
- Connects to `server@192.168.0.152` using shared cookie `bitcoin_secret`
- Spawns worker actors on Machine 2's CPU cores
- Requests work ranges from Machine 1 and sends all discovered coins back to Machine 1
- Remains silent on Machine 2

All coins found by **both** machines will appear on Machine 1's screen!

---

### Running Single-Node / Local Testing
You can also run both server and worker on a single machine or test in two separate terminal windows:

**Terminal 1 (Server):**
```powershell
.\project1.ps1 4
```

**Terminal 2 (Worker):**
```powershell
.\project1.ps1 127.0.0.1
```

---

## 3. Project Directory Structure

```
distributed_communcation_testing/
├── src/
│   ├── miner_util.erl    # SHA-256 hashing, binary leading-zeros check, hex encoder
│   ├── boss.erl          # Boss actor: problem range tracker, coin receiver & printer
│   ├── worker.erl        # Worker actor: batch miner, work requester
│   └── project1.erl      # CLI dispatcher (server vs worker detection)
├── ebin/                 # Compiled BEAM bytecode
├── project1.ps1          # PowerShell runner (auto-compiles, auto-detects IP)
├── project1.cmd          # Windows CMD batch wrapper
├── project1.sh           # Linux / macOS / WSL bash runner
├── setup_firewall.ps1    # Automated Windows Defender Firewall rule helper
└── README.md             # This documentation
```

---

## 4. Firewall & Network Configuration

If Machine 2 cannot ping or connect to Machine 1:
1. Ensure both laptops are connected to the same Wi-Fi and in the same subnet (`192.168.0.x`).
2. Run `setup_firewall.ps1` as Administrator on both machines:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\setup_firewall.ps1
   ```
   This automatically adds inbound firewall rules for `erl.exe`, `epmd.exe`, and TCP port `4369`.

---

## 5. Verification & Test Vectors

### COP5615 Test Vector Verification
The specification provides a test case:
- Input: `"COP5615 is a boring class"`
- Expected SHA-256: `fb4431b6a2df71b6cbad961e08fa06ee6fff47e3bc14e977f4b2ea57caee48a4`

Run the built-in verification anytime:
```powershell
erl -pa ebin -noshell -eval "io:format('Test vector: ~p~n', [miner_util:verify_test_vector()]), init:stop()."
```
Output:
```
Test vector: true
```

### Sample Output Format
Every coin discovered is output on independent lines separated by a TAB:
```
koppa;800178088855	00001c3f939b59525dadca5e4a147213f3190d4a2fee8074f69bd58f74422b8f
koppa;800178108273	00001676193dcca42384429d62fc7f4871faf67ecebf3403b8ebb11cc040cc46
koppa;800177957394	000004910dc79d1d158d97adba5e86fcb38cd10a68c9bcd0d80a87d8d34ffcdb
koppa;800178162374	00009961f40ea81fbff676f3d39c54eac6de324f23b2f05a18823a97156e669f
```
Each hash begins with the required number of `0`s and each string is prefixed with the gatorlink ID (`koppa;`). Custom prefixes can be passed as a second argument:
```powershell
.\project1.ps1 4 yourgatorlinkid
```
