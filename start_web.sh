#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8090}"
DEVICE="web-server"

usage() {
  cat <<EOF
Usage: ./start_web.sh [--chrome] [--port PORT] [--host HOST]

Starts offline_asset_book in Flutter debug mode.

Options:
  --chrome       Start with Flutter's Chrome device instead of web-server.
  --port PORT    Web server port. Default: ${PORT}
  --host HOST    Web server host. Default: ${HOST}
  -h, --help     Show this help.

Examples:
  ./start_web.sh
  ./start_web.sh --port 8091
  ./start_web.sh --chrome
EOF
}

prepare_port() {
  echo "Checking port ${PORT}..."
  local pids
  pids="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN || true)"

  if [[ -n "$pids" ]]; then
    echo "Port ${PORT} is already in use. Killing listening process(es):" >&2
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >&2
    echo >&2
    kill -9 $pids
    sleep 1
  fi

  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port ${PORT} is still in use after kill:" >&2
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >&2
    exit 1
  fi

  echo "Port ${PORT} is available."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chrome)
      DEVICE="chrome"
      shift
      ;;
    --port)
      PORT="${2:?Missing value for --port}"
      shift 2
      ;;
    --host)
      HOST="${2:?Missing value for --host}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter command not found. Install Flutter or add it to PATH." >&2
  exit 1
fi

if [[ "$DEVICE" == "chrome" ]]; then
  echo "Starting offline_asset_book with Flutter Chrome device..."
  echo "Hot reload: save in VS Code debug mode, or press r in this terminal."
  exec flutter run -d chrome
fi

prepare_port

echo "Starting offline_asset_book at http://${HOST}:${PORT}"
echo "Hot reload: press r in this terminal. Hot restart: press R. Quit: press q."
exec flutter run -d web-server --web-hostname "$HOST" --web-port "$PORT"
