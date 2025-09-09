# Simple helpers to create and push the repo with GitHub CLI

REPO := tizen-wgt-install-minimal
OWNER ?= $(shell gh api user -q .login 2>/dev/null || echo YOUR_GH_USERNAME)
REMOTE ?= origin
VIS ?= public
DESC := Minimal Dockerized installer for local Tizen .wgt to Samsung TV (Developer Mode)

.PHONY: help require-gh init repo-create repo-config push image-name ci-trigger

help:
	@echo "Targets:"
	@echo "  init          Initialize git repo on branch 'main' and commit files"
	@echo "  repo-create   Create $(REPO) on GitHub and push current main"
	@echo "  repo-config   Set description and topics on the repo"
	@echo "  push          Push main to remote $(REMOTE)"
	@echo "  image-name    Print GHCR image name"
	@echo "  ci-trigger    Create empty commit to trigger CI"

require-gh:
	@command -v gh >/dev/null 2>&1 || { \
	  echo "Error: GitHub CLI 'gh' not found. Install: https://cli.github.com/" >&2; \
	  exit 1; \
	}

init:
	@[ -d .git ] || git init
	@git checkout -B main
	@git add .
	@# Commit only if there is staged content
	@git diff --cached --quiet || git commit -m "init: minimal Tizen WGT installer"

repo-create: require-gh init
	gh repo create $(REPO) --$(VIS) --source=. --remote=$(REMOTE) --push

repo-config: require-gh
	gh repo edit $(OWNER)/$(REPO) \
	  --description "$(DESC)" \
	  --add-topic tizen \
	  --add-topic samsung \
	  --add-topic docker \
	  --add-topic tizen-studio

push:
	@git push -u $(REMOTE) main

image-name:
	@echo ghcr.io/$(OWNER)/$(REPO)

ci-trigger:
	@git commit --allow-empty -m "ci: trigger" && git push -u $(REMOTE) main

