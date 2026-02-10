#!/usr/bin/env bash
set -e

echo "Rendering README..."

# -------------------------
# sed portability
# -------------------------
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i)
else
  SED_INPLACE=(sed -i '')
fi

# -------------------------
# Config
# -------------------------
README_FILE="${README_FILE:-README.md}"
OWNER="${OWNER_OVERRIDE:-natekspencer}"

if [ -n "$REPO_OVERRIDE" ]; then
  REPO="$REPO_OVERRIDE"
elif [ -n "$GITHUB_REPOSITORY" ]; then
  REPO="${GITHUB_REPOSITORY##*/}"
else
  REPO="$(basename "$(pwd)")"
fi

HEADER="${HEADER:-homeassistant}"
FOOTERS="${FOOTERS:-support,star-history}"
CUSTOM_BADGES="${CUSTOM_BADGES:-}"
CHECK="${CHECK:-false}"
PROJECT_TYPE="${PROJECT_TYPE:-}"

FRAGMENTS_BASE="https://raw.githubusercontent.com/natekspencer/readme-fragments/main"

# -------------------------
# Temp files
# -------------------------
README_TMP=$(mktemp)
HEADER_TMP=$(mktemp)
FOOTER_TMP=$(mktemp)
INSTALLATION_TMP=$(mktemp)

# -------------------------
# Detect HACS type
# -------------------------
HACS_TYPE="custom"
tmp_hacs=$(mktemp)
curl -sSL https://raw.githubusercontent.com/hacs/default/master/integration -o "$tmp_hacs"
if grep -q "\"$OWNER/$REPO\"" "$tmp_hacs"; then
  HACS_TYPE="default"
fi
rm -f "$tmp_hacs"

# -------------------------
# Detect project type
# -------------------------
if [ -z "$PROJECT_TYPE" ]; then
  if [ -d "custom_components" ] || [ -f "hacs.json" ]; then
    PROJECT_TYPE="homeassistant"
  else
    PROJECT_TYPE="python"
  fi
fi

# -------------------------
# Extract integration domain and name
# -------------------------
DOMAIN=""
INTEGRATION_NAME=""
if [ -d "custom_components" ]; then
  read -r DOMAIN INTEGRATION_NAME < <(
    jq -r '[.domain, .name] | @tsv' custom_components/*/manifest.json 2>/dev/null | head -n1
  )
fi

# -------------------------
# Ensure managed blocks exist
# -------------------------
ensure_block() {
  local name="$1"
  local begin="<!-- BEGIN AUTO-GENERATED $name -->"
  local end="<!-- END AUTO-GENERATED $name -->"

  if ! grep -q "$begin" "$README_FILE"; then
    {
      cat "$README_FILE"
      echo
      echo "$begin"
      echo "$end"
    } > "$README_TMP"
    mv "$README_TMP" "$README_FILE"
  fi
}

ensure_block "HEADER"
ensure_block "INSTALLATION"
ensure_block "FOOTER"

# -------------------------
# Recursive expander
# -------------------------
expand_file() {
  local file="$1"
  local changed=true

  while $changed; do
    changed=false

    # 1️⃣ Variables
    "${SED_INPLACE[@]}" \
      -e "s/{{OWNER}}/$OWNER/g" \
      -e "s/{{REPO}}/$REPO/g" \
      -e "s/{{HACS_TYPE}}/$HACS_TYPE/g" \
      -e "s/{{DOMAIN}}/$DOMAIN/g" \
      "$file"

    # 2️⃣ INCLUDEs
    if grep -q '{{INCLUDE:' "$file"; then
      include=$(grep '{{INCLUDE:' "$file" | sed -E 's/.*\{\{INCLUDE:([^}]+)\}\}.*/\1/' | head -n1)

      include_url="$FRAGMENTS_BASE/$include.md"
      tmp_inc=$(mktemp)
      curl -sSL "$include_url" -o "$tmp_inc"

      expand_file "$tmp_inc"

      awk -v inc="$tmp_inc" -v key="{{INCLUDE:$include}}" '
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
      rm -f "$tmp_inc"
      changed=true
    fi
  done
}

# -------------------------
# Block injector
# -------------------------
inject_block() {
  local name="$1"
  local content="$2"

  local begin="<!-- BEGIN AUTO-GENERATED $name -->"
  local end="<!-- END AUTO-GENERATED $name -->"

  awk -v C="$content" -v B="$begin" -v E="$end" '
  $0 == B {
    print
    while ((getline l < C) > 0) print l
    close(C)
    skip=1
    next
  }
  $0 == E {
    print
    skip=0
    next
  }
  !skip { print }
  ' "$README_FILE" > "$README_TMP"

  mv "$README_TMP" "$README_FILE"
}

# -------------------------
# HEADER
# -------------------------
curl -sSL "$FRAGMENTS_BASE/headers/$HEADER/v1.md" -o "$HEADER_TMP"
expand_file "$HEADER_TMP"

if [ -n "$CUSTOM_BADGES" ]; then
  echo >> "$HEADER_TMP"
  echo "$CUSTOM_BADGES" >> "$HEADER_TMP"
fi

inject_block "HEADER" "$HEADER_TMP"

# -------------------------
# INSTALLATION
# -------------------------
curl -sSL "$FRAGMENTS_BASE/components/installation-hacs.md" -o "$INSTALLATION_TMP"
expand_file "$INSTALLATION_TMP"
inject_block "INSTALLATION" "$INSTALLATION_TMP"

# -------------------------
# FOOTER
# -------------------------
: > "$FOOTER_TMP"
IFS=',' read -ra ITEMS <<< "$FOOTERS"

for f in "${ITEMS[@]}"; do
  frag="$f"
  if [ "$f" = "support" ]; then
    frag="support-$PROJECT_TYPE"
  fi

  curl -sSL "$FRAGMENTS_BASE/footers/$frag.md" >> "$FOOTER_TMP"
  echo >> "$FOOTER_TMP"
done

expand_file "$FOOTER_TMP"
inject_block "FOOTER" "$FOOTER_TMP"

# -------------------------
# CI check
# -------------------------
if [ "$CHECK" = "true" ]; then
  if git diff --quiet "$README_FILE"; then
    echo "✅ README is up to date"
    exit 0
  else
    echo "::error::README managed sections are out of date"
    git diff
    exit 1
  fi
fi

echo "✅ README updated!"
