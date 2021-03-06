#!/usr/bin/env bash

set -e pipe
set -x

curl \
	https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml \
	| yq '[to_entries[] | {lang: .key, color: .value.color}]' \
	| sqlite-utils insert tmp.db linguist -

curl \
	-H "Accept: application/vnd.github.mercy-preview+json" \
	'https://api.github.com/users/cljoly/repos?page=1&sort=pushed&per_page=100' \
	| sqlite-utils insert tmp.db repo -

curl \
	-H "Accept: application/vnd.github.mercy-preview+json" \
	'https://api.github.com/search/issues?q=type:pr+author:cljoly&per_page=100' \
	| jq '.items' \
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

sqlite-utils create-view tmp.db featured_prs "SELECT DISTINCT \
	created_at, title, html_url, state, repository_url FROM prs \
	WHERE author_association <> 'OWNER' \
	AND title NOT LIKE '%typo%' \
	AND html_url NOT LIKE '%/joly122u/%' \
	AND created_at > '2018-12-31T00:00:00Z' \
	ORDER BY created_at DESC" > prs.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	created_at, title, html_url, state FROM featured_prs \
	ORDER BY created_at DESC" > prs.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	'https://github.com/' || substr(repository_url, 30) as repo_url, COUNT(*) pr_count \
	FROM featured_prs \
	GROUP BY repository_url \
	ORDER BY pr_count DESC" > contributed_repos.json

# =========

curl 'https://webmention.io/api/mentions.jf2?target=https://cj.rs'>webmentions.json

echo "JSONs created"

rm tmp.db
