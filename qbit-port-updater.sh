#!/bin/sh

is_debug=""
port_to_forward=""
cookie=""

QBIT_HOST="${QBIT_HOST:-localhost}"
QBIT_USER="${QBIT_USER:-}"
QBIT_PASSWORD="${QBIT_PASSWORD:-}"
QBIT_PORT="${QBIT_PORT:-8080}"

display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose       Enable verbose debug output"
    echo "  -p, --port PORT     Specify port to forward"
    echo "  -h, --help          Display this help message"
    echo ""
    echo "Environment Variables:"
    echo "  QBIT_HOST           Override default qBittorrent host (default: localhost)"
    echo "  QBIT_PORT           Override default qBittorrent port (default: 8080)"
    echo "  QBIT_USER           Set qBittorrent user name (this enables authentication)"
    echo "  QBIT_PASSWORD       Set qBittorrent account password"
    exit 0
}

display_vars() {
    if [ "$is_debug" = true ]; then
        echo "Debug Info:"
        echo "  QBIT_HOST=$QBIT_HOST"
        echo "  QBIT_PORT=$QBIT_PORT"
        echo "  QBIT_USER=$QBIT_USER"
        echo "  QBIT_PASSWORD=$QBIT_PASSWORD"
        echo "  port_to_forward=$port_to_forward"
        echo ""
    fi
}

parse_port() {
    local port=$1
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "$port"
    elif [[ "$port" =~ ^[0-9]+,[0-9]+$ ]]; then
        echo "$port" | cut -d',' -f1
    else
        echo "Error: Invalid port format. Must be a single number or a comma-separated list of numbers."
        exit 1
    fi
}

parse_args() {
    if [ "$#" -eq 0 ]; then
        display_help
    fi
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                echo "Verbose DEBUG enabled"
                is_debug=true
                ;;
            -p|--port)
                if [[ -n "$2" ]]; then
                    port_to_forward=$(parse_port "$2")
                    shift
                else
                    echo "Error: --port requires a value."
                    exit 1
                fi
                ;;
            -h|--help)
                display_help
                ;;
            *)
                echo "Unknown option: $1"
                display_help
                ;;
        esac
        shift
    done
}

login() {
    echo "Logging in to qBittorrent..."

    local url="http://$QBIT_HOST:$QBIT_PORT/api/v2/auth/login"
    local response=$(curl -s -i -X POST "$url" --data "username=$QBIT_USER&password=$QBIT_PASSWORD")
    cookie=$(echo "$response" | grep -i "set-cookie" | sed -E 's/.*set-cookie: ([^;]+);.*/\1/')

    if ! [ -n "$cookie" ]; then
        if [ -n "$is_debug" ]; then
            echo ""
            echo "curl -s -i -X POST '$url' --data 'username=$QBIT_USER&password=$QBIT_PASSWORD'"
            echo "Response:"
            echo "$response"
            echo "qBittorrent parsed cookie: $cookie"
            echo ""
        fi
        echo "No cookie found in the response $cookie"
        exit 1
    fi
}

logout() {
    echo "Logging out from qBittorrent..."
    local url="http://$QBIT_HOST:$QBIT_PORT/api/v2/auth/logout"
    local response=$(curl -s -i -X POST -b "$cookie" "$url")

    if [ -n "$is_debug" ]; then
        echo ""
        echo "curl -s -i -X POST -b '$cookie' '$url'"
        echo "Response:"
        echo "$response"
        echo ""
    fi

    if [[ "$response" == *"200 OK"* ]]; then
        echo "Logged out successfully."
    else
        echo "Failed to log out."
        exit 1
    fi
}

forward_port() {
    local port=$1
    local url="http://$QBIT_HOST:$QBIT_PORT/api/v2/app/setPreferences"
    local response=$(curl -s -i -X POST -b "$cookie" -d json={\"listen_port\":$port} "$url")

    if [ -n "$is_debug" ]; then
        echo ""
        echo "Request:"
        echo "curl -i -X POST -b '$cookie' -d json={\"listen_port\":$port} '$url'"
        echo "Response:"
        echo "$response"
        echo ""
    fi

    if [[ "$response" == *"200 OK"* ]]; then
        echo "Port $port forwarded successfully."
    else
        echo "Failed to forward port $port."
        exit 1
    fi
}

current_forwarded_port() {
    local url="http://$QBIT_HOST:$QBIT_PORT/api/v2/app/preferences"
    local response=$(curl -s -b "$cookie" "$url")
    local port=$(echo "$response" | jq -r '.listen_port')

    if [ -n "$is_debug" ]; then
        echo "" >&2
        echo "Request:" >&2
        echo "curl -s -b '$cookie' '$url'" >&2
        echo "Response:" >&2
        echo "$response" >&2
        echo "Current forwarded port: $port" >&2
        echo "" >&2
    fi

    echo "$port"
}

parse_args "$@"

display_vars

if [ -z "$port_to_forward" ]; then
    echo "Error: Port to forward is required. Use --port to specify."
    exit 1
fi

add_curl() {
    if ! command -v curl &> /dev/null; then
        echo "curl could not be found, installing..."
        if command -v apk &> /dev/null; then
            apk add curl
        fi
    else
        echo "curl is already installed."
    fi
}

add_curl

sleep 8 # Ensure that qBittorrent is up

login

# Jq is required to parse JSON responses
# But not installed in gluetun so current port will not be checked
current_port="" # $(current_forwarded_port)
# echo "Current forwarded port: $current_port"

if [ "$current_port" != "$port_to_forward" ]; then
    forward_port "$port_to_forward"
else
    echo "Port $port_to_forward is already forwarded."
fi

logout
exit 0
