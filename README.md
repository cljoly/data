# Data Repository for [cj.rs](https.//cj.rs/?ref=gh_data)


[![Build JSON data files](https://github.com/cljoly/data/actions/workflows/main.yml/badge.svg)](https://github.com/cljoly/data/actions/workflows/main.yml)
![GitHub deployments](https://img.shields.io/github/deployments/cljoly/data/github-pages?label=pages%20deployment)


Data sets to populate some parts of my website (mostly [cj.rs/open-source/](https://cj.rs/open-source/)).

## JSON Files

[gen_json.sh](./gen_json.sh) queries the GitHub API and fills SQLite database. Various queries are then used to generate JSON files, for use by [Hugo data templates](https://gohugo.io/templates/data-templates/)

                            ┌─────────────┐
       ┌────────────┐       │ gen_json.sh │       ┌────────┐
       │ GitHub API ├───────┴─────────────┴──────►│ *.json │
       └────────────┘                             └────────┘

## Repository Star Statistics

[stars.py](./stars.py) traces graphs of stars over time per repository.
