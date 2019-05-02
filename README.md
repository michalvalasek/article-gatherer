# Article Gatherer

This is a [FaastRuby](https://faastruby.io) lambda function that runs once a day: it scrapes supported websites for new articles and if it finds any, sends an email with links to these articles.

## Requirements

You'll need the `faastruby` gem installed. You'll also need [Sendgrid](https://sendgrid.com) account (for sending emails) and some online accessible Redis machine (e.g. [Redis Cloud](https://redislabs.com) service)

## Setup

1. Clone the repo.
2. Change the identifier in `project.yml`.
3. Copy `secrets.yml.example` to `secrets.yml` and put in the correct values.
4. Install faastruby cli: `gem install faastruby`
5. Run the project: `faastruby local`


## Deployment

Make sure you have unique project identifier in `project.yml` and correct values in `secrets.yml`.

- Deploy to staging: `faastruby deploy`
- Deploy to production: `faastruby deploy -e prod`
