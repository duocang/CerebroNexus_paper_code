#!/usr/bin/env bash
# kill the process tree listening on the given port(s) (Windows)
for p in "$@"; do
  for pid in $(netstat -ano | grep -E "[:.]$p +.*LISTENING" | awk '{print $5}' | sort -u); do taskkill //F //T //PID $pid >/dev/null 2>&1 && echo "killed $pid (port $p)"; done
done
