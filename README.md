# Article Gatherer

This is a [FaastRuby](https://faastruby.io) lambda function that runs once a day: it scrapes supported websites for new articles and if it finds any, sends an email with links to these articles.

## Requirements

You'll need the `faastruby` gem installed. You'll also need [Sendgrid](https://sendgrid.com) account (for sending emails) and some online accessible PostgreSQL machine (e.g. [ElephantSQL](https://elephantsql.com) service)

## Setup

1. Clone the repo.
2. Change the identifier in `project.yml`.
3. Copy `secrets.yml.example` to `secrets.yml` and put in the correct values.
4. Create databases (local and staging/production). See the next section for structure.
5. Install faastruby cli: `gem install faastruby`
5. Run the project: `faastruby local`

# Database

You need a postgres database with one table `articles` for storing the links that we already scraped, so that we don't send the same link twice.

Use this statement to create the table:
```
CREATE TABLE articles (
  id serial PRIMARY KEY,
  title varchar NOT NULL,
  url varchar NOT NULL,
  created_at date NOT NULL DEFAULT now()
);
ALTER TABLE articles ADD CONSTRAINT unique_title_url UNIQUE (title, url);
```

## Deployment

Make sure you have unique project identifier in `project.yml` and correct values in `secrets.yml`.

- Deploy to staging: `faastruby deploy`
- Deploy to production: `faastruby deploy -e prod`
