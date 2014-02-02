#!/usr/bin/env ruby
# encoding: utf-8

require 'net/http'
require 'json'

# parse command line arguments
user = ARGV[0]
if user == nil
  abort("Must supply an Instagram uername to download photos for as the first command line argument.")
end
cache = ARGV[1] == 'true'

# load config
begin
  file = File.open("config.json", "r")
  config = JSON.parse(file.read)
  file.close
rescue Errno::ENOENT
  abort("Must create a file named config.json with the proper configuration.")
end
instagram_api_url = config['instagram_api_url']
instagram_client_id = config['instagram_client_id']
image_save_location = config['image_save_location']
temp_dir = config['temp_dir']

puts "Config:"
puts "  instagram_api_url   = #{instagram_api_url}"
puts "  instagram_client_id = #{instagram_client_id}"
puts "  image_save_location = #{image_save_location}"
puts "  temp_dir            = #{temp_dir}"
puts "  user                = #{user}"
puts "  cache               = #{cache}"
puts ""

puts "Getting user id for username '#{user}'"

if (cache)
  file = File.open("#{temp_dir}/#{user}.json", "r")
  json = JSON.parse(file.read)
  file.close
else
  uri = URI("#{instagram_api_url}/users/search?q=#{user}&client_id=#{instagram_client_id}")
  Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new uri
    response = http.request request
    json = JSON.parse(response.body)
  end
  File.open("#{temp_dir}/#{user}.json", 'w') { |f| f.write(JSON.pretty_generate(json)) }
end

id = nil
json["data"].each { |e|
  id = e['id'] if (e['username'] == user)
}

puts "ID found: #{id}"

def get_media(uri, map)
  json = nil
  Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new uri
    response = http.request request
    json = JSON.parse(response.body)
  end
  json['data'].each { |e|
    map[e['created_time']] = URI(e['images']['standard_resolution']['url'])
  }
  next_url = json['pagination']['next_url']
  get_media(URI(next_url), map) if (next_url != nil)
end

puts "Getting image urls for user"

image_urls = {}
get_media(URI("#{instagram_api_url}/users/#{id}/media/recent/?client_id=#{instagram_client_id}"), image_urls)

image_urls.each_with_index { |(created_time,uri),index|
  next if index >= 5
  puts "Getting #{uri}"
  response = Net::HTTP.get_response(uri)
  File.open("#{image_save_location}/#{created_time}.jpg", 'w') { |f| f.write(response.body) }
}