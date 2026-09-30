#!/usr/bin/env bash
set -euo pipefail

# Rebuilt Codespaces can retain legacy Docker rules while Docker CE selects nft.
# Keep Docker on the same backend so bridge traffic and DNS work correctly.
if command -v iptables-legacy >/dev/null 2>&1 \
    && [ "$(readlink -f /usr/sbin/iptables)" != "$(readlink -f /usr/sbin/iptables-legacy)" ] \
    && sudo iptables-legacy -S FORWARD 2>/dev/null | grep -q -- '-j DOCKER'; then
    echo "Aligning Docker networking with existing iptables-legacy rules..."
    sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
    sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
    sudo pkill -TERM -x dockerd || true
    for attempt in $(seq 1 10); do
        if ! pgrep -x dockerd >/dev/null; then
            break
        fi
        sleep 1
    done
    if pgrep -x dockerd >/dev/null; then
        echo "Docker did not stop cleanly; inspect it before retrying." >&2
        exit 1
    fi
    sudo /usr/local/share/docker-init.sh
fi
