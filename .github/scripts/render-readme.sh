#!/usr/bin/env bash
set -e

# -------------------------
# Config / environment
# -------------------------
README_FILE="${README_FILE:-README.md}"
OWNER="${OWNER_OVERRIDE:-natekspencer}"

# Auto-detect REPO:
# - Use override if set
# - Otherwise use GitHub Actions env
# - Otherwise use current folder name (local)
if [ -n "$REPO_OVERRIDE" ]; then
    REPO="$REPO_OVERRIDE"
elif [ -n "$GITHUB_REPOSITORY" ]; then
    REPO="${GITHUB_REPOSITORY##*/}"
else
    REPO="$(basename $(pwd))"
fi

HEADER="${HEADER:-ha}"
FOOTERS="${FOOTERS:-support,star-history}"
CHECK="${CHECK:-false}"
CUSTOM_BADGES="${CUSTOM_BADGES:-}"
CUSTOM_BADGES_FILE="${CUSTOM_BADGES_FILE:-}"

# -------------------------
# Temporary files
# -------------------------
HEADER_TMP=$(mktemp)
FOOTER_TMP=$(mktemp)
README_TMP=$(mktemp)

# -------------------------
# 1️⃣ Fetch header fragment
# -------------------------
HEADER_URL="https://raw.githubusercontent.com/natekspencer/readme-fragments/main/headers/$HEADER/v1.md"
curl -sSL "$HEADER_URL" -o "$HEADER_TMP"

# Replace placeholders
sed -i \
  -e "s/{{OWNER}}/$OWNER/g" \
  -e "s/{{REPO}}/$REPO/g" \
  "$HEADER_TMP"

# Add custom badges inline
if [ -n "$CUSTOM_BADGES" ]; then
  echo >> "$HEADER_TMP"
  echo "$CUSTOM_BADGES" >> "$HEADER_TMP"
fi

# Add custom badges from file
if [ -n "$CUSTOM_BADGES_FILE" ] && [ -f "$CUSTOM_BADGES_FILE" ]; then
  echo >> "$HEADER_TMP"
  cat "$CUSTOM_BADGES_FILE" >> "$HEADER_TMP"
fi

# -------------------------
# 2️⃣ Inject header
# -------------------------
awk -v HEADER_FILE="$HEADER_TMP" '
/<!-- BEGIN AUTO-GENERATED HEADER -->/ {
    print
    while ((getline line < HEADER_FILE) > 0) print line
    close(HEADER_FILE)
    skip=1
    next
}
/<!-- END AUTO-GENERATED HEADER -->/ {
    print
    skip=0
    next
}
!skip { print }
' "$README_FILE" > "$README_TMP"

# -------------------------
# 3️⃣ Build footers
# -------------------------
: > "$FOOTER_TMP"
IFS=',' read -ra ITEMS <<< "$FOOTERS"
for f in "${ITEMS[@]}"; do
  FOOTER_URL="https://raw.githubusercontent.com/natekspencer/readme-fragments/main/footers/$f.md"
  curl -sSL "$FOOTER_URL" >> "$FOOTER_TMP"
  echo >> "$FOOTER_TMP"
done

# Replace placeholders in footer
sed -i \
  -e "s/{{OWNER}}/$OWNER/g" \
  -e "s/{{REPO}}/$REPO/g" \
  "$FOOTER_TMP"

# -------------------------
# 4️⃣ Inject footer
# -------------------------
awk -v FOOTER_FILE="$FOOTER_TMP" '
/<!-- BEGIN AUTO-GENERATED FOOTER -->/ {
    print
    while ((getline line < FOOTER_FILE) > 0) print line
    close(FOOTER_FILE)
    skip=1
    next
}
/<!-- END AUTO-GENERATED FOOTER -->/ {
    print
    skip=0
    next
}
!skip { print }
' "$README_TMP" > "$README_FILE"

# -------------------------
# 5️⃣ Optional CI check
# -------------------------
if [ "$CHECK" = "true" ]; then
  if git diff --quiet "$README_FILE"; then
    echo "✅ README is up to date"
    rm -f "$HEADER_TMP" "$FOOTER_TMP" "$README_TMP"
    exit 0
  else
    echo "::error::README managed sections are out of date"
    git diff
    rm -f "$HEADER_TMP" "$FOOTER_TMP" "$README_TMP"
    exit 1
  fi
fi

# -------------------------
# 6️⃣ Cleanup temp files
# -------------------------
rm -f "$HEADER_TMP" "$FOOTER_TMP" "$README_TMP"
