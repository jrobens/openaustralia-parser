#!/usr/bin/env ruby

$:.unshift "#{File.dirname(__FILE__)}/lib"

require 'rubygems'

# seems to be custom to open australia
#require 'mechanize_proxy'
require 'mechanize'
require 'configuration'
require 'people'
require 'tempfile'

# use a file cache
require 'parsed_url_cache'

defined? Nokogiri

# Find the list of divisions from the AEC website for each postcode the Australia Post postcodes database.
#
# Implement a squid cache on the front - e.g. on port 9999.
class ParsePostcode

  conf = Configuration.new

#agent = MechanizeProxy.new
#agent.cache_subdirectory = "parse-postcodes"

  def initialize()
    @cache = ParsedUrlCache.new()

    @mech = Mechanize.new do |agent|
      agent.user_agent_alias = 'Mac Safari'
      agent.set_proxy('localhost',9999)
    end
  end


  # Just load the html
  def load_page(postcode)
    page = @mech.get("http://apps.aec.gov.au/esearch/LocalitySearchResults.aspx?filter=#{postcode}&filterby=Postcode")
  end


  def extract_divisions_from_page(page)
    postcodes = []
    #   puts page.inspect
    # TODO - move to configuration
    page.links_with(:href => /LocalitySearchResults.aspx/).each do |location_link|
      # ignore any 4 digit filters - aka postcodes
      puts "checking #{location_link.text}"
      check_link_regex = Regexp.new('\d{4}')
      if location_link.text !~ check_link_regex
        puts "adding #{location_link.text}"
        postcodes << location_link.text
      end

      # page.search('table').first.search('tr').each do |row_tag|
      #   td_tag = row_tag.search(' td')[3]
      #   if td_tag
      #     postcode = td_tag.search('a').inner_text
      #     if postcode.nil?
      #       puts "Nil postcode in division #{division}"
      #     end
      #     postcodes << postcode
      #   end
    end

    postcodes
  end

  def other_pages?(page)
    table_tag = page.search('table')[1]
    false
    # TODO - causes crash
#    !table_tag.search('> tr > td > a').map { |e| e.inner_text }.empty?
  end

  def cache key, val
    tf = Tempfile.new('googletrends', @path)
    path = tf.path
    tf.close! # important!

    puts2 "Saving to cache (#{path})"
    open(path, 'w') { |f|
      f.write(val)
      @cache[key] = path
    }

    save @datafile
  end

  def cache_exists? key
    @cache.has_key? key
  end

  def uncache key
    return nil unless exists?(key) && File.exists?(@cache[key])
    open(@cache[key], 'r') { |f| f.read }
  end

  private
  # Load saved cache
  def load file
    return File.exists?(file) ? YAML.load(open(file).read) : {}
  end

  # Save cache
  def save path
    open(path, 'w') { |f|
      f.write @cache.to_yaml
    }
  end

end
#  ParsePostcode


postcode_parser = ParsePostcode.new()

file = File.open("data/postcodes.csv", "w")
puts "Writing postcodes to data/postcodes.csv"

file.puts("Postcode,Electoral division name")
file.puts(",")

puts "Reading Australia post office data from data/pc-full_20080529.csv..."
data = CSV.readlines("data/pc-full_20080529.csv")

# Ignore header
data.shift

valid_postcodes = data.map { |row| row.first }.uniq.sort

valid_postcodes.each do |postcode|
  page = postcode_parser.load_page(postcode)

  divisions = postcode_parser.extract_divisions_from_page(page)

  if postcode_parser.other_pages?(page)
    puts "WARNING: Multiple pages of data for postcode #{postcode}"
    file.puts("*** Double check data for postcode #{postcode} by hand ***")
  end

  if divisions.empty?
    puts "No divisions for postcode #{postcode}"
  else
    divisions.uniq.sort.each do |division|
      file.puts "#{postcode},#{division}"
    end
  end
end
