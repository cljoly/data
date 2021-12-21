#!/usr/bin/env python3

import sqlite_utils
import dateutil.parser
from datetime import datetime
import pygal
import os

os.system("~/.local/bin/git-history file stars.db unarchived_repos.json --branch master")

stars_over_time_by_repo = sqlite_utils.Database("stars.db")
rows = stars_over_time_by_repo.query("""SELECT name, min(pushed_at) as pushed_at, stargazers_count FROM item WHERE pushed_at > "2020-01-01" AND stargazers_count > 2 GROUP BY name, pushed_at ORDER BY name, pushed_at""")
stars_over_time_by_repo = {}
for row in rows:
    repo = row['name']
    l = stars_over_time_by_repo.get(repo, [])
    l.append((dateutil.parser.isoparse(row['pushed_at']), row['stargazers_count']))
    stars_over_time_by_repo[repo] = l

datetimeline = pygal.DateTimeLine(
    legend_at_bottom=True,
    x_label_rotation=35, truncate_label=-1,
    x_value_formatter=lambda dt: dt.strftime('%d, %b %Y at %I:%M:%S %p'))

for repo, points in stars_over_time_by_repo.items():
    datetimeline.add(repo, points)

datetimeline.render_to_file("stars.svg")
