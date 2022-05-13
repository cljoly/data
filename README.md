# data

Data sets to populate some parts of my website (mostly cj.rs/open-source/).

## JSON Files

[gen_json.sh](./gen_json.sh) queries the GitHub API and fills SQLite database. Various queries are then used to generate JSON files, for use by [Hugo data templates](https://gohugo.io/templates/data-templates/)

                            ┌─────────────┐
       ┌────────────┐       │ gen_json.sh │       ┌────────┐
       │ GitHub API ├───────┴─────────────┴──────►│ *.json │
       └────────────┘                             └────────┘

## Repository Star Statistics

[stars.py](./stars.py) traces graphs of stars over time per repository.
