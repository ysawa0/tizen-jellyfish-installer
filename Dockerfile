FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG TIZEN_STUDIO_URL="https://download.tizen.org/sdk/Installer/tizen-studio_5.5/web-cli_Tizen_Studio_5.5_ubuntu-64.bin"

ENV TIZEN_HOME=/opt/tizen \
    PATH="/opt/tizen/tools/ide/bin:/opt/tizen/tools:$PATH"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash curl unzip ca-certificates xz-utils jq openjdk-17-jre-headless \
      tar lsb-release gawk; \
    rm -rf /var/lib/apt/lists/*

# Validate URL host and install Tizen Studio CLI headlessly
RUN set -eux; \
    url="$TIZEN_STUDIO_URL"; \
    host="$(printf %s "$url" | awk -F/ '{print $3}')"; \
    case "$host" in \
      developer.samsung.com|*.developer.samsung.com|tizen.org|*.tizen.org|download.tizen.org) ;; \
      *) echo "Refusing to download from non-official host: $host" >&2; exit 1;; \
    esac; \
    curl -fL "$url" -o /tmp/tizen-cli.bin; \
    chmod +x /tmp/tizen-cli.bin; \
    echo "Running Tizen Studio CLI installer..."; \
    /tmp/tizen-cli.bin --accept-license --no-java-check --path "$TIZEN_HOME" > /tmp/tizen_install.log 2>&1; \
    inst_status=$?; \
    if [ "$inst_status" -ne 0 ]; then \
      echo "Tizen Studio CLI installer failed (exit $inst_status)." >&2; \
      echo "Installer output:" >&2; \
      cat /tmp/tizen_install.log >&2 || true; \
      echo "If this persists, try overriding TIZEN_STUDIO_URL to a newer official URL." >&2; \
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
    # Verify CLI binaries with helpful logs on failure
    if ! command -v sdb >/dev/null 2>&1; then \
      echo "Error: sdb not found on PATH." >&2; \
      echo "Installer output:" >&2; cat /tmp/tizen_install.log >&2 || true; \
      exit 1; \
    fi; \
    sdb version; \
    if ! command -v tizen >/dev/null 2>&1; then \
      echo "Error: tizen CLI not found on PATH." >&2; \
      echo "Installer output:" >&2; cat /tmp/tizen_install.log >&2 || true; \
      exit 1; \
    fi; \
    tizen --version; \
    rm -f /tmp/tizen-cli.bin

COPY ./entrypoint.sh /usr/local/bin/tizen-wgt-install
RUN chmod +x /usr/local/bin/tizen-wgt-install

ENTRYPOINT ["/usr/local/bin/tizen-wgt-install"]
