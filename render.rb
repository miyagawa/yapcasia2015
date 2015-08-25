#!/usr/bin/env ruby
# coding: utf-8
require 'haml'
require 'yaml'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'uri'
require 'open_uri_redirections'
require 'time'
require 'active_support/cache'

def tweak_image(url)
  case url
  when /twimg\.com/
    url.sub(/_normal\./, '_bigger.')
  when /graph\.facebook\.com/
    url + '?type=square&width=240'
  else
    url
  end
end

def ucfirst(txt)
  txt.sub(/^(\w)/, &:capitalize)
end

def gcal_link(talk)
  start  = Time.parse(talk["start_on"] + " +0900")
  finish = start + talk["duration"].to_i * 60
  
  uri = URI("https://www.google.com/calendar/event")
  uri.query = URI.encode_www_form(
    action: "TEMPLATE",
    text: (talk["title"] || talk["title_en"]) + " - " + talk["speaker"]["name"],
    dates: start.utc.strftime('%Y%m%dT%H%M%SZ') + '/' + finish.utc.strftime('%Y%m%dT%H%M%SZ'),
    location: talk["venue"],
  )
  uri
end

def oembed(url)
  cache = ActiveSupport::Cache::FileStore.new('.cache', expires_in: 1.day)
  cache.fetch("oembed:#{url}") do
    JSON.parse(open(url, allow_redirections: :safe).read)["html"]
  end
end

def embed(url)
  case url
  when /slideshare/
    oembed("http://www.slideshare.net/api/oembed/2?url=#{URI.encode_www_form_component url}&maxwidth=600&format=json")
  when /speakerdeck\.com\//
    oembed("http://speakerdeck.com/oembed.json?url=#{URI.encode_www_form_component url}&maxwidth=600")
  when /docs\.google\.com\/presentation\/d\/(.*?)\/(pub|mobile)/
    %Q(<iframe width="600" height="480" src="https://docs.google.com/presentation/d/#{$1}/embed" frameborder="0"></iframe>)
  when /drive\.google\.com\/open\?id=(.*)/
    %Q(<iframe width="600" height="480" src="https://drive.google.com/file/d/#{$1}/preview" frameborder="0"></iframe>)
  when nil
    nil
  else
    %Q(<iframe width="600" height="480" src="#{url}" width="600" height="480" frameborder="0"></iframe>)
  end
end

def get_talk_details(talk)
  {
    "id" => talk["id"],
    "title" => talk["title"] || talk["title_en"],
    "title_en" => talk["title_en"],
    "avatar" => tweak_image(talk["speaker"]["profile_image_url"]),
    "speaker" => talk["speaker"]["name"],
    "nickname" => talk["speaker"]["nickname"],
    "description" => talk["abstract_html"],
    "labels" => [ ucfirst(talk["category"]), ucfirst(talk["material_level"]) ],
    "duration" => talk["duration"],
    "language" => talk["language"] == "ja" ? "Japanese" : "English",
    "gcal" => gcal_link(talk),
    "video_url" => talk["video_url"],
    "presentation" => embed(talk["slide_url"]),
  }
end

schedule = YAML.load(File.read("schedule.yml"))

talk_data = {}
%W[day0 day1 day2].each do |file|
  data = JSON.parse(File.read("#{file}.json"))
  data["talks_by_venue"].each do |venue_talks|
    venue_talks.each do |talk|
      talk_data[talk["id"]] = talk.merge("venue" => data["venue_id2name"][talk["venue_id"]])
    end
  end
end

schedule.each do |event|
  event["slots"].each do |slot|
    slot["hour"]  = [slot["hour"]].flatten
    slot["talks"] = slot["talks"].map { |talks|
      [talks].flatten.map {|talk_id|
        if talk_id
          get_talk_details(talk_data[talk_id])
        else
          nil
        end
      }
    }
  end
end

engine = Haml::Engine.new(File.read("index.haml"))
puts engine.render(binding)
