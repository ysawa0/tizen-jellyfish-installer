FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

ENV TIZEN_HOME=/opt/tizen \
    PATH="/opt/tizen/tools/ide/bin:/opt/tizen/tools:$PATH"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash curl unzip ca-certificates xz-utils jq openjdk-17-jre-headless \
      tar lsb-release gawk; \
    rm -rf /var/lib/apt/lists/*

# Copy pre-downloaded official Tizen Studio web/CLI installer from repo
COPY ./bin/ /tmp/bin/

# Install Tizen Studio CLI from local installer
RUN set -eux; \
    # Reassemble installer if split into parts: *.part-001, *.part-002, ...
    if ls /tmp/bin/*.part-* >/dev/null 2>&1; then \
      echo "Reassembling installer from parts..."; \
      cat $(ls -1 /tmp/bin/*.part-* | sort) > /tmp/bin/installer.bin; \
      installer="/tmp/bin/installer.bin"; \
    else \
      installer="$(ls /tmp/bin/*.bin 2>/dev/null | head -n1 || true)"; \
    fi; \
    if [ -z "$installer" ]; then \
      echo "Error: No installer .bin found in ./bin. Place the official Tizen Studio web CLI .bin there." >&2; \
      exit 1; \
    fi; \
    # Optional: verify checksum if provided as ./bin/installer.sha256
    if [ -f /tmp/bin/installer.sha256 ]; then \
      echo "Verifying installer checksum..."; \
      (cd /tmp/bin && sha256sum -c installer.sha256); \
    fi; \
    chmod +x "$installer"; \
    echo "Running Tizen Studio CLI installer: $(basename "$installer")"; \
    "$installer" --accept-license --no-java-check --path "$TIZEN_HOME" > /tmp/tizen_install.log 2>&1; \
    inst_status=$?; \
    if [ "$inst_status" -ne 0 ]; then \
      echo "Tizen Studio CLI installer failed (exit $inst_status)." >&2; \
      echo "Installer output:" >&2; cat /tmp/tizen_install.log >&2 || true; \
      exit "$inst_status"; \
    fi; \
    # Best-effort: install Samsung TV extension if discoverable via CLI
    pm="$TIZEN_HOME/package-manager/package-manager-cli.bin"; \
    if [ -x "$pm" ]; then \
      set +e; \
      "$pm" list | awk -F'|' 'tolower($0) ~ /tv/ {print $1}' | while read -r pkg; do \
        [ -n "$pkg" ] && "$pm" install --accept-license "$pkg" || true; \
      done; \
      set -e; \
    fi; \
    # Verify CLI binaries with helpful logs on failure (avoid set -e masking post-check logs)
    set +e; \
    command -v sdb >/dev/null 2>&1; sdb_ok=$?; \
    command -v tizen >/dev/null 2>&1; tizen_ok=$?; \
    if [ "$sdb_ok" -ne 0 ]; then \
      echo "Error: sdb not found on PATH." >&2; echo "Installer output:" >&2; cat /tmp/tizen_install.log >&2 || true; exit 1; \
    fi; \
    if [ "$tizen_ok" -ne 0 ]; then \
      echo "Error: tizen CLI not found on PATH." >&2; echo "Installer output:" >&2; cat /tmp/tizen_install.log >&2 || true; exit 1; \
    fi; \
    sdb version || true; tizen --version || true; \
    set -e

COPY ./entrypoint.sh /usr/local/bin/tizen-wgt-install
RUN chmod +x /usr/local/bin/tizen-wgt-install

ENTRYPOINT ["/usr/local/bin/tizen-wgt-install"]
