require 'nokogiri'
require 'open-uri'
require 'redis'
require 'sendgrid-ruby'
require 'erubis'

include SendGrid

def handler(event)
  env = JSON.parse(event.context)
  redis = Redis.new(url: env['redis'])

  sites = {
    appsignal: 'https://blog.appsignal.com/',
    martians: 'https://evilmartians.com/chronicles',
    skylight: 'https://blog.skylight.io',
    devto_elixir: 'https://dev.to/t/elixir',
    devto_ruby: 'https://dev.to/t/ruby',
    morning_paper: 'https://blog.acolyer.org'
  }

  scraped = sites.map do |site, url|
    send("scrape_#{site}", Nokogiri::HTML(open(url))) rescue nil
  end.flatten.compact

  filtered = scraped.select do |item|
    redis.sadd('gathered', Oj.dump(item))
  end

  if filtered.size > 0
    sg_resp = send_email(env, build_email_content(filtered))
  end

  render json: {
    scraped: scraped,
    filtered: filtered,
    sg_response: sg_resp.inspect
  }
end

def scrape_appsignal(doc)
  doc.css('article header a').map do |a|
    {
      site_title: 'App Signal',
      title: a.css('h1:first').text.strip.gsub(/\s{2,}/, ' '),
      url: "https://blog.appsignal.com#{a[:href]}"
    }
  end
end

def scrape_martians(doc)
  doc.css('a.post-list__item').map do |a|
    {
      site_title: 'Evil Martians',
      title: a.css('h1.post-cover__title').text.strip.gsub(/\s{2,}/, ' '),
      url: "https://evilmartians.com#{a[:href]}"
    }
  end
end

def scrape_skylight(doc)
  doc.css('h2.post-title>a').map do |a|
    {
      site_title: 'Skylight',
      title: a.text.strip.gsub(/\s{2,}/, ' '),
      url: "https://blog.skylight.io#{a[:href]}"
    }
  end
end

def scrape_devto(doc, section)
  doc.css('a.index-article-link').map do |a|
    {
      site_title: "DEV.to - #{section}",
      title: a.css('.content h3').xpath('text()').text.strip.gsub(/\s{2,}/, ' '),
      url: "https://dev.to#{a[:href]}"
    }
  end
end
def scrape_devto_ruby(doc); scrape_devto(doc, 'Ruby') end
def scrape_devto_elixir(doc); scrape_devto(doc, 'Elixir') end

def scrape_morning_paper(doc)
  doc.css('h1.entry-title>a').map do |a|
    {
      site_title: 'Morning Paper',
      title: a.text.strip.gsub(/\s{2,}/, ' '),
      url: a[:href]
    }
  end
end

def build_email_content(items)
  grouped = items.group_by {|item| item[:site_title] }
  body = Erubis::Eruby.new(File.read('email.html.erb')).result(groups: grouped)
  SendGrid::Content.new(type: 'text/html', value: body)
end

def send_email(env, content)
  sg = SendGrid::API.new(api_key: env['sendgrid'])

  from = SendGrid::Email.new(email: env['emails_from'])
  to = SendGrid::Email.new(email: env['emails_to'])
  subject = "Gatherer: New articles from #{Date.today}"
  mail = SendGrid::Mail.new(from, subject, to, content)

  sg.client.mail._('send').post(request_body: mail.to_json)
end
