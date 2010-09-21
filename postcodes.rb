#!/usr/bin/env ruby

# Load the postcode data directly into the database

$:.unshift "#{File.dirname(__FILE__)}/lib"

# in `require': no such file to load -- mysql (LoadError)
require 'rubygems'
require 'active_support/core_ext'


require 'csv'
require 'mysql'
require 'configuration'
require 'people'
# mysql required 
#require 'i18n'

conf = Configuration.new

def quote_string(s)
  s.gsub(/\\/, '\&\&').gsub(/'/, "''") # ' (for ruby-mode)
end

divisions = CSV.readlines("data/postcodes.csv")
# Remove the first two elements
divisions.shift
divisions.shift

puts "Reading members data..."
people = PeopleCSVReader.read_members
all_members = people.all_periods_in_house(House.representatives)

all_members.each do |mem|
  puts mem.division
end

# First check that all the constituencies are valid
constituencies = divisions.map { |row| row[1] }.uniq
constituencies.each do |constituency|
 # throw "Constituency #{constituency} not found" unless all_members.any? {|m| m.division == constituency}
  puts "Constituency #{constituency} not found" unless all_members.any? {|m| m.division == constituency}
  puts "***Constituency #{constituency}  found" if all_members.any? {|m| m.division == constituency}

end

db = Mysql.real_connect(conf.database_host, conf.database_user, conf.database_password, conf.database_name)

# Clear out the old data
db.query("DELETE FROM postcode_lookup")

#values = divisions.map {|row| "('#{row[0]}', '#{quote_string(row[1])}')" }.join(',')
#db.query("INSERT INTO postcode_lookup (postcode, name) VALUES #{values}")
