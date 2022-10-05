#!/usr/bin/env ruby

require 'csv'
require 'yaml'
require 'json'
require 'uri'
require 'net/http'
require 'net/https'
require 'stringio'

API_URL = 'https://api.developers.italia.it/v1'
API_BEARER_TOKEN = ENV['API_BEARER_TOKEN']

def post_publisher(body)
  uri = URI("#{API_URL}/publishers")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri)
  request.content_type = "application/json"
  request['Authorization'] = "Bearer #{API_BEARER_TOKEN}"
  request.body = body

  res = http.request(request)
  STDERR.puts("failed: #{res.body} request: #{body}\n") if not res.is_a?(Net::HTTPSuccess)
end

if ARGV.length < 1
  STDERR.puts "Usage:"
  STDERR.puts
  STDERR.puts "Import publishers from YAML file"
  STDERR.puts "$ ./api-import.rb publishers.yml"
  STDERR.puts
  STDERR.puts "Import from onboarded PAs"
  STDERR.puts "$ ./api-import.rb --onboarded"

  exit(false)
end

onboarded = ARGV.first == '--onboarded'

ipa = {}

ipa_file = `curl -L 'https://www.indicepa.gov.it/public-services/opendata-read-service.php?dstype=FS&filename=amministrazioni.txt'`
CSV.new(StringIO.new(ipa_file), col_sep: "\t", quote_char: nil, return_headers: false).each do |row|
  ipa[row.first.downcase] = row
  ipa[row[18].downcase] = row if row[18]
end

if onboarded
  repo_list = `curl -L https://onboarding.developers.italia.it/repo-list`

  pecs = {}
  pec_file = `curl -L 'https://www.indicepa.gov.it/public-services/opendata-read-service.php?dstype=FS&filename=pec.txt'`
  CSV.new(StringIO.new(pec_file), col_sep: "\t", quote_char: nil, return_headers: false).each do |row|
    pecs[row[7].downcase] = row
  end

  urls = {}
  publishers = {}
  repo_list = YAML.load(repo_list)['registrati']
  repo_list.each do |publisher|
    pec = publisher['pec'].downcase
    name = pecs.dig(pec, 1) || pec

    urls[publisher['ipa']] ||= []
    urls[publisher['ipa']] << { "url" => publisher['url'] }

    publishers[publisher['ipa']] = {
      "description" => name,
      "email" => pec,
      "externalCode" => publisher['ipa'],
      "codeHosting" => urls[publisher['ipa']],
    }
  end

  publishers.each do |k, v|
    post_publisher(v.to_json)
  end
else
  YAML.load_file(ARGV.first).each do |publisher|
    code_hosting = []
    code_hosting += publisher['repos'].map{|repo| {"url": repo, "group": false} } if publisher['repos']
    code_hosting += publisher['orgs'].map{|org| {"url": org } } if publisher['orgs']

    ipa_code = publisher['id']&.downcase
    name = publisher['name'] || ipa[ipa_code][1]
    pec = publisher['id'] ? ipa[ipa_code][18] : ''

    post_publisher({
      "description" => name,
      "email" => pec,
      "externalCode" => publisher['id'],
      "codeHosting": code_hosting,
    }.to_json)
  end
end
