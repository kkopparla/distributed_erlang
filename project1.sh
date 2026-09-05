#!/usr/bin/env bash
# Distributed Bitcoin Mining Runner (Bash for Linux/macOS/WSL)

COOKIE="bitcoin_secret"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p ebin

# Check for compilation
NEEDS_COMPILE=false
for src in src/*.erl; do
    base=$(basename "$src" .erl)
    beam="ebin/${base}.beam"
    if [ ! -f "$beam" ] || [ "$src" -nt "$beam" ]; then
        NEEDS_COMPILE=true
        break
    fi
done

if [ "$NEEDS_COMPILE" = true ]; then
    echo "[*] Compiling Erlang source files..."
    erlc -W -o ebin src/*.erl
    if [ $? -ne 0 ]; then
        echo "Compilation failed."
        exit 1
    fi
fi

if [ -z "$1" ]; then
    echo "Usage:"
    echo "  Server mode: ./project1.sh <leading_zeros> [prefix]"
    echo "               Example: ./project1.sh 4"
    echo "  Worker mode: ./project1.sh <server_ip>"
    echo "               Example: ./project1.sh 192.168.0.152"
    exit 0
fi

# Detect Local IP
LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $7;exit}')
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="127.0.0.1"
fi

if [[ "$1" =~ ^[0-9]+$ ]]; then
    # Server mode
    NODE_NAME="server@${LOCAL_IP}"
    echo "============================================================"
    echo " Starting Server Node: $NODE_NAME"
    echo " Target: $1 leading zeros"
    echo " Listening on IP: $LOCAL_IP"
    echo " Connect workers via: ./project1.sh $LOCAL_IP"
    echo "============================================================"
    exec erl -pa ebin -name "$NODE_NAME" -setcookie "$COOKIE" -noshell -run project1 main "$@"
else
    # Worker mode
    RAND_ID=$((RANDOM % 9000 + 1000))
    NODE_NAME="worker_${RAND_ID}@${LOCAL_IP}"
    echo "============================================================"
    echo " Starting Worker Node: $NODE_NAME"
    echo " Connecting to Server: $1"
    echo " Silent mode: All found coins are printed on Server."
    echo "============================================================"
    exec erl -pa ebin -name "$NODE_NAME" -setcookie "$COOKIE" -noshell -run project1 main "$1"
fi
