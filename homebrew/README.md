# Homebrew Tap for BlueTeam Autopilot

This directory contains the Homebrew formula for installing BlueTeam Autopilot.

## Installation

```bash
# Add the tap
brew tap cdavis-code/blueteam

# Install
brew install blueteam-autopilot
```

## Updating the formula for a new release

The formula is **automatically updated** by a GitHub Actions workflow when a new release is published.

### Manual trigger (if needed)

If you need to manually update the formula:

1. Go to **Actions → Update Homebrew Formula** in the blueteam-autopilot repo
2. Click **Run workflow**
3. Enter the release tag (e.g., `v3.1.1`)

### How it works

The workflow (`.github/workflows/homebrew.yml`):
1. Downloads the release tarball from GitHub
2. Computes the SHA256 hash
3. Updates `Formula/blueteam-autopilot.rb` in the homebrew-blueteam repo
4. Commits and pushes the change

### Required secret

The workflow requires a `HOMEBREW_TAP_TOKEN` secret in the blueteam-autopilot repo settings. This should be a GitHub PAT with `repo` scope for the `cdavis-code/homebrew-blueteam` repository.

## Repository setup

This formula should be hosted in a separate repository: `cdavis-code/homebrew-blueteam`

```bash
# Create the tap repo
cd /path/to/scratch
git init homebrew-blueteam
cd homebrew-blueteam
cp -r /path/to/blueteam/homebrew/* .
git add .
git commit -m "Initial formula"
git remote add origin https://github.com/cdavis-code/homebrew-blueteam.git
git push -u origin main
```
