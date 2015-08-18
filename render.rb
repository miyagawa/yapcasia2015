#!/usr/bin/env ruby
# coding: utf-8
require 'haml'
require 'yaml'
require 'nokogiri'
require 'open-uri'
require 'active_support/cache'

def tweak_image(url)
  case url
  when /twimg\.com/
    url.sub(/_normal\./, '.')
  when /graph\.facebook\.com/
    url + '?type=square&width=240'
  else
    url
  end
end

def get_talk_details(id)
  warn "---> Getting Talk details for #{id}"
  doc = Nokogiri::HTML(open("http://yapcasia.org/2015/talk/show/#{id}").read)
  {
    "id" => id,
    "title" => doc.at_css('title').text.sub(/ - YAPC::Asia Tokyo 2015/, ''),
    "avatar" => tweak_image(doc.at_css('.large-1 img')["src"]),
    "speaker" => doc.at_css('.large-1').children[3].text,
    "description" => doc.at_css('.abstract').inner_html.sub(/<h1>.*?<\/h1>\n/, ''),
    "labels" => [ doc.at_css('table').children[5].children[3].text, doc.at_css('table').children[15].children[3].text ],
    "duration" => doc.at_css('table').children[13].children[3].text,
    "language" => doc.at_css('table').children[7].children[3].text, 
  }.tap { |data| warn data.inspect }
end

cache = ActiveSupport::Cache::FileStore.new('.cache', expires_in: 1.day)

@schedule = YAML.load(File.read("schedule.yml"))

@schedule.each do |event|
  event["slots"].each do |slot|
    slot["hour"]  = [slot["hour"]].flatten
    slot["talks"] = slot["talks"].map { |talks|
      [talks].flatten.map {|talk_id|
        if talk_id
          cache.fetch("talk:#{talk_id}") { get_talk_details(talk_id) }
        else
          nil
        end
      }
    }
  end
end

engine = Haml::Engine.new(File.read("index.haml"))
puts engine.render(binding)
