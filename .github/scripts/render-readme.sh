#!/usr/bin/env bash
echo "Rendering README..."

# -------------------------
# sed portability (macOS vs GNU)
# -------------------------
if sed --version >/dev/null 2>&1; then
  # GNU sed
  SED_INPLACE=(sed -i)
else
  # BSD sed (macOS)
  SED_INPLACE=(sed -i '')
fi

set -e

# -------------------------
# Config / environment
# -------------------------
README_FILE="${README_FILE:-README.md}"
OWNER="${OWNER_OVERRIDE:-natekspencer}"

# Auto-detect REPO:
if [ -n "$REPO_OVERRIDE" ]; then
    REPO="$REPO_OVERRIDE"
elif [ -n "$GITHUB_REPOSITORY" ]; then
    REPO="${GITHUB_REPOSITORY##*/}"
else
    REPO="$(basename $(pwd))"
fi

HEADER="${HEADER:-homeassistant}"
FOOTERS="${FOOTERS:-support,star-history}"
CHECK="${CHECK:-false}"
CUSTOM_BADGES="${CUSTOM_BADGES:-}"
PROJECT_TYPE="${PROJECT_TYPE:-}"

# -------------------------
# Ensure header/footer markers exist
# -------------------------

# Header: insert at top if missing
if ! grep -q '<!-- BEGIN AUTO-GENERATED HEADER -->' "$README_FILE"; then
    tmp=$(mktemp)
    if [ -s "$README_FILE" ]; then
        echo -e "<!-- BEGIN AUTO-GENERATED HEADER -->\n<!-- END AUTO-GENERATED HEADER -->\n" > "$tmp"
        cat "$README_FILE" >> "$tmp"
    else
        echo -e "<!-- BEGIN AUTO-GENERATED HEADER -->\n<!-- END AUTO-GENERATED HEADER -->" > "$tmp"
    fi
    mv "$tmp" "$README_FILE"
fi

# Footer: append at end if missing
if ! grep -q '<!-- BEGIN AUTO-GENERATED FOOTER -->' "$README_FILE"; then
    echo -e "\n<!-- BEGIN AUTO-GENERATED FOOTER -->\n<!-- END AUTO-GENERATED FOOTER -->" >> "$README_FILE"
fi

# -------------------------
# Temporary files
# -------------------------
HEADER_TMP=$(mktemp)
FOOTER_TMP=$(mktemp)
README_TMP=$(mktemp)

# -------------------------
# 1️⃣ Detect HACS default vs custom
# -------------------------
HACS_TYPE="custom"
tmp_hacs_list=$(mktemp)
curl -sSL https://raw.githubusercontent.com/hacs/default/master/integration -o "$tmp_hacs_list"
if grep -q "\"$OWNER/$REPO\"" "$tmp_hacs_list"; then
    HACS_TYPE="default"
fi
rm -f "$tmp_hacs_list"

# -------------------------
# Detect project type (homeassistant vs python)
# -------------------------
if [ -z "$PROJECT_TYPE" ]; then
  if [ -f "hacs.json" ] || [ -d "custom_components" ]; then
    PROJECT_TYPE="homeassistant"
  else
    PROJECT_TYPE="python"
  fi
fi

# -------------------------
# 2️⃣ Fetch header fragment
# -------------------------
HEADER_URL="https://raw.githubusercontent.com/natekspencer/readme-fragments/main/headers/$HEADER/v1.md"
curl -sSL "$HEADER_URL" -o "$HEADER_TMP"

# Replace placeholders
"${SED_INPLACE[@]}" \
  -e "s/{{OWNER}}/$OWNER/g" \
  -e "s/{{REPO}}/$REPO/g" \
  -e "s/{{HACS_TYPE}}/$HACS_TYPE/g" \
  "$HEADER_TMP"

# Add custom badges inline
if [ -n "$CUSTOM_BADGES" ]; then
  echo >> "$HEADER_TMP"
  echo "$CUSTOM_BADGES" >> "$HEADER_TMP"
fi

# -------------------------
# 3️⃣ Inject header
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
# 4️⃣ Build footers with include support
# -------------------------
expand_includes() {
  local file="$1"

  while grep -q '{{INCLUDE:' "$file"; do
    include=$(grep '{{INCLUDE:' "$file" | sed -E 's/.*\{\{INCLUDE:([^}]+)\}\}.*/\1/')
    include_file="https://raw.githubusercontent.com/natekspencer/readme-fragments/main/footers/${include}.md"

    tmp_include=$(mktemp)
    curl -sSL "$include_file" -o "$tmp_include"

    awk -v inc="$tmp_include" -v key="{{INCLUDE:$include}}" '
      {
        if ($0 ~ key) {
          while ((getline l < inc) > 0) print l
          close(inc)
        } else {
          print
        }
      }
    ' "$file" > "$file.tmp"

    mv "$file.tmp" "$file"
    rm -f "$tmp_include"
  done
}

: > "$FOOTER_TMP"
IFS=',' read -ra ITEMS <<< "$FOOTERS"
for f in "${ITEMS[@]}"; do
  fragment="$f"

  # Pick the correct support file based on project type
  if [ "$f" = "support" ]; then
    fragment="support-$PROJECT_TYPE"
  fi

  FOOTER_URL="https://raw.githubusercontent.com/natekspencer/readme-fragments/main/footers/$fragment.md"
  curl -sSL "$FOOTER_URL" >> "$FOOTER_TMP"
  expand_includes "$FOOTER_TMP"
  echo >> "$FOOTER_TMP"
done

# Replace placeholders in footers
"${SED_INPLACE[@]}" \
  -e "s/{{OWNER}}/$OWNER/g" \
  -e "s/{{REPO}}/$REPO/g" \
  "$FOOTER_TMP"

# -------------------------
# 5️⃣ Inject footer
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
# 6️⃣ Optional CI check
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
# 7️⃣ Cleanup temp files
# -------------------------
rm -f "$HEADER_TMP" "$FOOTER_TMP" "$README_TMP"

echo "✅ README updated!"