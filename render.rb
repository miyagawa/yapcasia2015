#!/usr/bin/env ruby
# coding: utf-8
require 'haml'
require 'yaml'
require 'nokogiri'
require 'open-uri'
require 'json'

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

def get_talk_details(talk)
  {
    "id" => talk["id"],
    "title" => talk["title"] || talk["title_en"],
    "title_en" => talk["title_en"],
    "avatar" => tweak_image(talk["speaker"]["profile_image_url"]),
    "speaker" => talk["speaker"]["name"],
    "description" => talk["abstract_html"],
    "labels" => [ ucfirst(talk["category"]), ucfirst(talk["material_level"]) ],
    "duration" => talk["duration"],
    "language" => talk["language"] == "ja" ? "Japanese" : "English",
  }
end

schedule = YAML.load(File.read("schedule.yml"))

talk_data = {}
%W[day0 day1 day2].each do |file|
  JSON.parse(File.read("#{file}.json"))["talks_by_venue"].each do |venue_talks|
    venue_talks.each do |talk|
      talk_data[talk["id"]] = talk
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
