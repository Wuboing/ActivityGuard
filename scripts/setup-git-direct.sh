#!/bin/bash
# Configure this repo to reach GitHub directly (bypass githubproxy.cc).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

git config --local remote.origin.url https://github.com/Wuboing/ActivityGuard.git
git config --local --unset-all url.https://githubproxy.cc/github.com/.insteadOf 2>/dev/null || true
git config --local --unset-all url.https://github.com/.insteadOf 2>/dev/null || true
git config --local --unset-all url.https://github.com/.pushInsteadOf 2>/dev/null || true
git config --local --unset-all url.git@github.com:.insteadOf 2>/dev/null || true

git config --local alias.p "!f() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -c credential.helper='!gh auth git-credential' push \"\$@\"; }; f"
git config --local alias.pl "!f() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -c credential.helper='!gh auth git-credential' pull \"\$@\"; }; f"
git config --local alias.f "!f() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -c credential.helper='!gh auth git-credential' fetch \"\$@\"; }; f"

cat <<'EOF'
Configured direct GitHub commands for this repo:

  git p   origin <branch>   # push  (直连，不走 githubproxy)
  git pl  origin <branch>   # pull
  git f   origin            # fetch

Run once after clone: bash scripts/setup-git-direct.sh
EOF
