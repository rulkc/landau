#!/usr/bin/env bash
# Spell-check Markdown sources using hunspell with ru_RU + en_US dictionaries.
# Words listed in .spellcheck-allow.txt are accepted as correct.
#
# Usage: scripts/spellcheck.sh [paths...]
# Default scope when no args given: content/, docs/, README.md, AGENTS.md.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ALLOW="${ROOT}/.spellcheck-allow.txt"
[ -f "${ALLOW}" ] || { echo "missing allow list: ${ALLOW}" >&2; exit 1; }

cd "${ROOT}"

PATHS=("$@")
if [ "${#PATHS[@]}" -eq 0 ]; then
  PATHS=(content docs README.md AGENTS.md)
fi

# Build the file list. Avoid `mapfile`/`readarray` so the script runs on
# Bash 3.2 (macOS default) as well as Linux's modern bash.
files=()
while IFS= read -r line; do
  [ -n "${line}" ] && files+=("${line}")
done < <(
  for p in "${PATHS[@]}"; do
    [ -e "${p}" ] || continue
    if [ -d "${p}" ]; then
      find "${p}" -type f -name '*.md'
    else
      printf '%s\n' "${p}"
    fi
  done | sort -u
)

if [ "${#files[@]}" -eq 0 ]; then
  echo "no markdown files found"
  exit 0
fi

# Sanity check: confirm hunspell can actually load both dictionaries.
# (On some environments — e.g. GitHub Actions ubuntu-24.04 runner image —
# Ubuntu's hunspell-ru / hunspell-en-us packages can install successfully
# but leave /usr/share/hunspell/ stripped of the .aff/.dic files. Set
# DICPATH to a directory containing ru_RU.{aff,dic} and en_US.{aff,dic} as
# a workaround.)
if echo 'архитектура' | hunspell -d ru_RU,en_US -l | grep -qx 'архитектура'; then
  echo "::error::hunspell ru_RU dictionary not loaded properly"
  echo "DICPATH=${DICPATH:-(unset)}"
  hunspell -D 2>&1 | head -30
  exit 1
fi
if echo 'architecture' | hunspell -d ru_RU,en_US -l | grep -qx 'architecture'; then
  echo "::error::hunspell en_US dictionary not loaded properly"
  echo "DICPATH=${DICPATH:-(unset)}"
  hunspell -D 2>&1 | head -30
  exit 1
fi

# Explicit template — bare `mktemp` errors on macOS/BSD (`too few X's in template`).
unknown=$(mktemp "${TMPDIR:-/tmp}/landau-spellcheck.XXXXXX")
trap 'rm -f "${unknown}"' EXIT

for f in "${files[@]}"; do
  awk '
    BEGIN { fm = 0; code = 0 }
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    fm && /^---[[:space:]]*$/      { fm = 0; next }
    fm                             { next }
    /^[[:space:]]*```/             { code = !code; next }
    code                           { next }
    {
      gsub(/<[^>]*>/, " ")                              # HTML tags
      gsub(/`[^`]*`/, " ")                              # inline code spans
      gsub(/https?:\/\/[^[:space:])]+/, " ")            # URLs
      gsub(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/, " ")     # emails
      gsub(/[][(){}|*_~#]/, " ")                        # markdown punctuation
      # Strip invisible Unicode chars that confuse hunspell tokenizer.
      # Byte sequences below are the UTF-8 encodings of:
      gsub(/\xef\xb8\x8f/, " ")                         # U+FE0F variation selector-16
      gsub(/\xef\xb8\x8e/, " ")                         # U+FE0E variation selector-15
      gsub(/\xe2\x80\x8d/, " ")                         # U+200D zero-width joiner
      gsub(/\xe2\x80\x8c/, " ")                         # U+200C zero-width non-joiner
      gsub(/\xe2\x80\x8b/, " ")                         # U+200B zero-width space
      print
    }
  ' "$f" \
  | hunspell -d ru_RU,en_US -l \
  >> "${unknown}"
done

# Empty unknown list = nothing to filter; happy exit.
if [ ! -s "${unknown}" ]; then
  echo "Spell check OK across ${#files[@]} files."
  exit 0
fi

# Filter accumulated unknowns against the allow list (exact, fixed strings).
sort -u "${unknown}" -o "${unknown}"
filtered=$(grep -vxFf "${ALLOW}" "${unknown}" || true)

if [ -n "${filtered}" ]; then
  echo "::error::Unknown words found in markdown sources:"
  printf '%s\n' "${filtered}" | sed 's/^/  /'
  echo
  echo "If these are intentional (proper nouns, technical terms),"
  echo "add them to .spellcheck-allow.txt. Otherwise, fix the spelling."
  exit 1
fi

echo "Spell check OK across ${#files[@]} files."
