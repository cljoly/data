#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi
cd "$(dirname "$0")"

# Start fresh
if [[ -f tmp.db ]]; then
    rm tmp.db
fi

curl \
	https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml \
	| yq '[to_entries[] | {lang: .key, color: .value.color}]' \
	| sqlite-utils insert tmp.db linguist -

sleep 10
gh api --paginate \
	-H "Accept: application/vnd.github.mercy-preview+json" \
	'https://api.github.com/users/cljoly/repos?page=1&sort=pushed' \
	| jq -s 'flatten(1)' \
	| sqlite-utils insert tmp.db repo -

sleep 10
gh api --paginate \
	-H "Accept: application/vnd.github.mercy-preview+json" \
	-q '.items' \
	'https://api.github.com/search/issues?q=type:pr+author:cljoly' \
	| jq -s 'flatten(1)' \
	| sqlite-utils insert tmp.db prs -

echo "data retrieved"

sqlite-utils create-view tmp.db topic "SELECT DISTINCT \
	repo.rowid as rid, json_each.value as t \
	FROM repo, json_each(topics)"

sqlite-utils create-view tmp.db featured_repo "SELECT DISTINCT \
	repo.rowid AS rowid, private, pushed_at, name, html_url, topics, description, \
	stargazers_count, homepage, archived, language, color \
	FROM repo \
	JOIN linguist ON lang = repo.language \
	WHERE \
	(fork <> 1 OR rowid IN (SELECT rid FROM topic WHERE t = 'maintained-fork')) \
	AND stargazers_count > 0 AND rowid NOT IN (SELECT rid FROM topic WHERE t = 'internal') \
	AND private == 0"

echo "views created"

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid NOT IN (SELECT rid FROM topic WHERE t = 'archived') \
	AND rowid NOT IN (SELECT rid FROM topic WHERE t = 'wip') \
	AND archived == 0 \
	ORDER BY pushed_at DESC" > unarchived_repos.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid NOT IN (SELECT rid FROM topic WHERE t = 'archived') \
	AND rowid NOT IN (SELECT rid FROM topic WHERE t = 'wip') \
	AND archived == 0 \
	ORDER BY stargazers_count DESC" > unarchived_most_stars_repos.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid IN (SELECT rid FROM topic WHERE t = 'archived') \
	OR archived == 1 \
	ORDER BY pushed_at DESC" > archived_repos.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid IN (SELECT rid FROM topic WHERE t = 'wip') \
	AND archived == 0 \
        ORDER BY pushed_at DESC" > wip_repos.json

# -------
# Special requests

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid NOT IN (SELECT rid FROM topic WHERE t = 'archived') \
	AND rowid NOT IN (SELECT rid FROM topic WHERE t = 'wip') \
	AND rowid IN (SELECT rid FROM topic WHERE t = 'neovim-plugin') \
	AND archived == 0 \
	ORDER BY stargazers_count DESC" > unarchived_nvim_most_stars_repos.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid IN (SELECT rid FROM topic WHERE t = 'wip') \
	AND rowid IN (SELECT rid FROM topic WHERE t = 'neovim-plugin') \
	AND archived == 0 \
        ORDER BY pushed_at DESC" > wip_nvim_repos.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid IN (SELECT rid FROM topic WHERE t = 'hugo-module') \
	AND archived == 0 \
        ORDER BY pushed_at DESC" > hugo_modules_repos.json

# -------

sqlite-utils create-view tmp.db featured_prs "SELECT DISTINCT \
	created_at, title, html_url, state, repository_url \
    FROM prs \
	WHERE author_association <> 'OWNER' \
	AND title NOT LIKE '%typo%' \
	AND html_url NOT LIKE '%/joly122u/%' \
	AND created_at > '2018-12-31T00:00:00Z' \
	ORDER BY created_at DESC"

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	created_at, title, html_url, state \
    FROM featured_prs \
	ORDER BY created_at DESC" > prs.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	'https://github.com/' || substr(repository_url, 30) as repo_url, COUNT(*) pr_count \
	FROM featured_prs \
	GROUP BY repository_url \
	ORDER BY pr_count DESC" > contributed_repos.json

# =========

curl 'https://webmention.io/api/mentions.jf2?target=https://cj.rs'>webmentions.json

# =========

# Should be fine with GitHub limits since it’s a small number of read-only
# requests:
# https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28
for repo in telescope-repo.nvim bepo.nvim minimal-format.nvim
do
    gh api https://api.github.com/repos/cljoly/${repo}/traffic/clones?per=week | jq --compact-output '.clones | sort_by(.timestamp) | .[-2] | {schemaVersion: 1, label: "clones/week", message: .count, color: "purple"}' >./nvim/${repo/.nvim/}.json
done

echo "JSONs created"
