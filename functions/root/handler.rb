require 'nokogiri'
require 'open-uri'
require 'sequel'
require 'sendgrid-ruby'
require 'erubis'

include SendGrid

def handler(event)
  env = JSON.parse(event.context)
  db = Sequel.connect(env['postgres'])

  sites = {
    appsignal: 'https://blog.appsignal.com/'
  }

  scraped = sites.map do |site, url|
    next if !respond_to?(:"scrape_#{site}")
    send("scrape_#{site}", Nokogiri::HTML(open(url)))
  end.flatten.compact

  filtered = scraped.select do |item|
    begin
      db[:articles].insert(item.slice(:title, :url)) == 1
    rescue Sequel::UniqueConstraintViolation
      false
    end
  end

  if filtered.size > 0
    sg_resp = send_email(env, build_email_content(filtered))
  end

  render json: {
    scraped: scraped,
    filtered: filtered,
    sg_response: sg_resp
  }
end

def scrape_appsignal(doc)
  doc.css('article header a').map do |a|
    {
      site_title: 'App Signal Blog',
      title: a.css('h1:first').text.strip.gsub(/\s{2,}/, ' '),
      url: "https://blog.appsignal.com#{a[:href]}"
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
  to = SendGrid::Email.new(email: env['email_to'])
  subject = "Gatherer: New articles from #{Date.today}"
  mail = SendGrid::Mail.new(from, subject, to, content)

  sg.client.mail._('send').post(request_body: mail.to_json)
end
