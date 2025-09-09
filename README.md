# tizen-wgt-install-minimal

Minimal, auditable Docker image that installs a local .wgt to a Samsung TV (Tizen) in Developer Mode. No extra scripts, no network downloads of your app, only the official Tizen Studio CLI inside the image.

## Prereqs
- TV and your machine on the same LAN/subnet.
- Enable Developer Mode on TV: Home → Apps → enter 12345 → Developer Mode ON → reboot.
- Default developer port is 26101 (override with --port if you changed it).

## Quickstart
1) Place your .wgt in the current folder.
2) Build image
   - Intel/AMD: `docker build -t tizen-wgt-install-minimal:0.1.0 .`
   - Apple Silicon: `docker buildx build --platform linux/amd64 -t tizen-wgt-install-minimal:0.1.0 .`
   - Optional: `docker build -t tizen-wgt-install-minimal:0.1.0 --build-arg TIZEN_STUDIO_URL=<official_Tizen_CLI_installer_URL> .`
3) Install
   - `docker run --rm -v "$PWD:/work" tizen-wgt-install-minimal:0.1.0 192.168.1.50 --wgt /work/Jellyfin.wgt`
   - With custom port: `docker run --rm -v "$PWD:/work" tizen-wgt-install-minimal:0.1.0 192.168.1.50 --wgt /work/Jellyfin.wgt --port 26101`

## Notes
- The image downloads only the official Tizen Studio CLI at build time.
- Some TV firmwares require a Samsung distributor certificate. If tizen install reports a signing error, create/import certificates with the official Tizen tools outside this container and repackage your .wgt as required (not covered here; kept minimal by design).

## Troubleshooting
- device offline / cannot connect: verify TV IP, same subnet, Developer Mode ON, correct port (26101).
- tizen not found: rebuild; build must succeed installing Tizen CLI.
- install failed / signature: indicates certificate/signing requirement on your firmware.
# tizen-jellyfish-installer

Local installer chunks
- To avoid GitHub’s 100MB limit, split the official Tizen Studio web CLI installer into parts and commit the parts under `./bin`.
- Example (from the directory containing the original `.bin` file):
  - `mkdir -p bin`
  - `split -b 50m web-cli_Tizen_Studio_5.5_ubuntu-64.bin bin/tizen-cli.bin.part-`
  - `sha256sum web-cli_Tizen_Studio_5.5_ubuntu-64.bin | awk '{print $1 "  installer.bin"}' > bin/installer.sha256`
  - `git add bin/ && git commit -m "add Tizen installer chunks"`
  - The Dockerfile reassembles `bin/tizen-cli.bin.part-*` into `/tmp/bin/installer.bin` and verifies `bin/installer.sha256` if present.
