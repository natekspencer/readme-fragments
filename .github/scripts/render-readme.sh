#!/usr/bin/env bash
set -e

README_FILE=README.md

OWNER="${OWNER_OVERRIDE:-natekspencer}"
REPO="${REPO_OVERRIDE:-${GITHUB_REPOSITORY##*/}}"
HEADER="${HEADER:-homeassistant}"
FOOTERS="${FOOTERS:-support,star-history}"
CHECK="${CHECK:-false}"
CUSTOM_BADGES="${CUSTOM_BADGES:-}"

# Fetch header fragment
curl -sSL "https://raw.githubusercontent.com/natekspencer/readme-fragments/main/headers/$HEADER/v1.md" -o header.tmp.md

# Replace owner/repo placeholders
sed -i \
  -e "s/{{OWNER}}/$OWNER/g" \
  -e "s/{{REPO}}/$REPO/g" \
  header.tmp.md

# Inject custom badges
if [ -n "$CUSTOM_BADGES" ]; then
  echo >> header.tmp.md
  echo "$CUSTOM_BADGES" >> header.tmp.md
fi

# Inject header
awk '
/<!-- BEGIN AUTO-GENERATED HEADER -->/ { print; system("cat header.tmp.md"); skip=1; next }
/<!-- END AUTO-GENERATED HEADER -->/ { skip=0; next }
!skip { print }
' "$README_FILE" > README.tmp.md

# Build footers
: > footer.tmp.md
IFS=',' read -ra ITEMS <<< "$FOOTERS"
for f in "${ITEMS[@]}"; do
  if [ -f "footers/$f.md" ]; then
    cat "footers/$f.md" >> footer.tmp.md
    echo >> footer.tmp.md
  fi
done

# Inject footer
awk '
/<!-- BEGIN AUTO-GENERATED FOOTER -->/ { print; system("cat footer.tmp.md"); skip=1; next }
/<!-- END AUTO-GENERATED FOOTER -->/ { skip=0; next }
!skip { print }
' README.tmp.md > "$README_FILE"

# CI check
if [ "$CHECK" = "true" ]; then
  if git diff --quiet "$README_FILE"; then
    echo "README is up to date"
    exit 0
  else
    echo "::error::README managed sections are out of date"
    git diff
    exit 1
  fi
fi
