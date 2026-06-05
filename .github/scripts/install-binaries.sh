#!/usr/bin/env bash
# Install pinned Terraform, Terragrunt, and (optionally) tf-summarize into
# BIN_DIR and prepend it to PATH. Downloads are skipped on a cache hit.
#
# Usage: install-binaries.sh <bin_dir> <tf_ver> <tg_ver> [tfsum_ver] [cache_hit]
set -euo pipefail

BIN_DIR="${1:?bin dir required}"
TF_VER="${2:?terraform version required}"
TG_VER="${3:?terragrunt version required}"
TFSUM_VER="${4:-}"
CACHE_HIT="${5:-false}"

mkdir -p "$BIN_DIR"

if [ "$CACHE_HIT" != "true" ]; then
  echo "Cache miss — downloading binaries..."

  curl -fL -o "${RUNNER_TEMP}/terraform.zip" \
    "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip"
  unzip -o "${RUNNER_TEMP}/terraform.zip" -d "$BIN_DIR/"
  rm -f "${RUNNER_TEMP}/terraform.zip"

  curl -fL -o "$BIN_DIR/terragrunt" \
    "https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VER}/terragrunt_linux_amd64"

  if [ -n "$TFSUM_VER" ]; then
    curl -fL -o "${RUNNER_TEMP}/tf-summarize.tar.gz" \
      "https://github.com/dineshba/tf-summarize/releases/download/v${TFSUM_VER}/tf-summarize_linux_amd64.tar.gz"
    tar -xzf "${RUNNER_TEMP}/tf-summarize.tar.gz" -C "$BIN_DIR/" tf-summarize
    rm -f "${RUNNER_TEMP}/tf-summarize.tar.gz"
    chmod +x "$BIN_DIR/tf-summarize"
  fi

  chmod +x "$BIN_DIR/terraform" "$BIN_DIR/terragrunt"
else
  echo "Cache hit — using cached binaries."
fi

echo "--- Binary verification ---"
ls -lh "$BIN_DIR/terraform" "$BIN_DIR/terragrunt"
if [ -n "$TFSUM_VER" ]; then
  ls -lh "$BIN_DIR/tf-summarize"
fi
echo "---------------------------"
echo "$BIN_DIR" >> "$GITHUB_PATH"
