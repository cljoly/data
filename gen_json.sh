#!/usr/bin/env bash

set -e pipe
set -x

curl \
	-H "Accept: application/vnd.github.mercy-preview+json" \
	'https://api.github.com/users/cljoly/repos?page=1&sort=pushed&per_page=100' \
	| sqlite-utils insert tmp.db repo -

curl \
	-H "Accept: application/vnd.github.mercy-preview+json" \
	'https://api.github.com/search/issues?q=type:pr+is:merged+author:cljoly&per_page=100' \
	| jq '.items' \
	| sqlite-utils insert tmp.db prs -

echo "data retrieved"

sqlite-utils create-view tmp.db topic "SELECT DISTINCT \
	repo.rowid as rid, json_each.value as t \
	FROM repo, json_each(topics)"

sqlite-utils create-view tmp.db featured_repo "SELECT DISTINCT \
	rowid, private, pushed_at, name, html_url, topics, description, stargazers_count \
	FROM repo WHERE \
	(fork <> 1 OR rowid IN (SELECT rid FROM topic WHERE t = 'maintained-fork')) \
	AND stargazers_count > 0 \
	AND private == 0"

echo "views created"

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid NOT IN (SELECT rid FROM topic WHERE t = 'archived') \
	ORDER BY pushed_at DESC" > unarchived_repos.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid NOT IN (SELECT rid FROM topic WHERE t = 'archived') \
	ORDER BY pushed_at DESC" > unarchived_repos.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid IN (SELECT rid FROM topic WHERE t = 'archived') \
	ORDER BY pushed_at DESC" > archived_repos.json

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	* \
	FROM featured_repo \
	WHERE rowid IN (SELECT rid FROM topic WHERE t = 'wip') \
	ORDER BY pushed_at DESC" > wip_repos.json

# -------

sqlite-utils query tmp.db --json-cols "SELECT DISTINCT \
	created_at, title, html_url, state FROM prs \
	WHERE author_association <> 'OWNER' \
	AND title NOT LIKE '%typo%' \
	AND state = 'closed' \
	AND html_url NOT LIKE '%/joly122u/%' \
	AND created_at > '2018-12-31T00:00:00Z' \
	ORDER BY created_at DESC" > prs.json

echo "JSONs created"

rm tmp.db
