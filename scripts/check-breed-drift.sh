#!/usr/bin/env bash
#
# check-breed-drift.sh
#
# Verifies that ios/Trot/Trot/Resources/BreedData.json and
# web/api/breed-data.json are byte-identical. Both files derive from
# docs/breed-table.md and must stay in sync — divergence means either the
# iOS app and the LLM proxy are picking targets from different breed lists,
# or one of the two files was hand-edited and the other forgotten.
#
# Run from the project root, or via `npm run check-drift` in web/.
# Exits 0 on parity, 1 on drift, 2 on missing files.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IOS_JSON="$ROOT/ios/Trot/Trot/Resources/BreedData.json"
WEB_JSON="$ROOT/web/api/breed-data.json"

if [[ ! -f "$IOS_JSON" ]]; then
    echo "error: missing $IOS_JSON" >&2
    exit 2
fi

if [[ ! -f "$WEB_JSON" ]]; then
    echo "error: missing $WEB_JSON" >&2
    exit 2
fi

if diff -q "$IOS_JSON" "$WEB_JSON" > /dev/null; then
    BREED_COUNT=$(python3 -c "import json; print(len(json.load(open('$IOS_JSON'))['breeds']))")
    echo "ok: $BREED_COUNT breeds, both copies identical"
    exit 0
fi

echo "error: BreedData.json copies have drifted." >&2
echo "" >&2
echo "iOS:  $IOS_JSON" >&2
echo "web:  $WEB_JSON" >&2
echo "" >&2
echo "Both files derive from docs/breed-table.md. After editing the" >&2
echo "table, regenerate both JSON copies and verify with this script." >&2
echo "" >&2
echo "diff:" >&2
diff "$IOS_JSON" "$WEB_JSON" | head -40 >&2
exit 1
