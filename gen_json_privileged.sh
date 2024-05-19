#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi
cd "$(dirname "$0")"

# Meant to run with a token with extended privileges

# Should be fine with GitHub limits since it’s a small number of read-only
# requests:
# https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28
for repo in telescope-repo.nvim bepo.nvim minimal-format.nvim
do
    # https://developer.github.com/v3/repos/traffic/#clones
    # A new badge is generated on the Monday, so we can cache for about a day
    # Takes the numbers from the penultimate entry in the array, under the
    # assumption that the current week is the last item
    gh api https://api.github.com/repos/cljoly/${repo}/traffic/clones?per=week | \
        jq --compact-output '.clones | sort_by(.timestamp) | .[-2] | {schemaVersion: 1, label: "clones/week", message: (.count + 0 | tostring), color: "purple"}' \
        >./nvim/${repo/.nvim/}.json
done

echo "JSONs created"
