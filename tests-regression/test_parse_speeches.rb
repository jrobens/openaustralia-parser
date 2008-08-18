#!/usr/bin/env ruby
#
# Simple implementation of regression tests for xml generated by parse-speeches.rb
# N.B. Need to pre-populate reference xml files with those that have previously been generated.
# In other words, this is only useful for checking that any refactoring has not caused a regression in behaviour.
#

$:.unshift "#{File.dirname(__FILE__)}/../lib"

require 'people'
require 'hansard_parser'
require 'configuration'

# Range of dates to test

from_date = Date.new(2007, 1, 1)
to_date = Date.new(2008, 1, 1) - 1

# Number of items to skip at the beginning
skip = 0

# Dates to test first before anything else
# Update this list with any dates that have shown up problems in the past

test_first = [Date.new(2007,8,8), Date.new(2007,8,14)]

skip_dates = []

#

conf = Configuration.new

# First load people back in so that we can look up member id's
people = PeopleCSVReader.read_members

parser = HansardParser.new(people)

def compare_xml(path1, path2)
  if File.exists?(path1) && File.exists?(path2)
    command = "diff #{path2} #{path1}"
    puts command
    system(command)
    if $? != 0
      test = "regression_failed_text.xml"
      ref = "regression_failed_ref.xml"
      #system("rm -f #{test} #{ref}")
      system("tidy -xml -o #{test} #{path2}")
      system("tidy -xml -o #{ref} #{path1}")
      system("opendiff #{test} #{ref}")
      puts "ERROR: #{path2} and #{path1} don't match"
      puts "Regression tests FAILED on date #{date} at count #{count}!"
      exit
    end
  elsif File.exists?(path1)
    puts "ERROR: #{path2} is missing"
    puts "Regression tests FAILED on date #{date} at count #{count}!"
    exit
  elsif File.exists?(path2)
    puts "ERROR: #{path1} is missing"
    puts "Regression tests FAILED on date #{date} at count #{count}!"
    exit
  end
end

def test_date(date, conf, parser, count)
  reps_xml_filename = "debates#{date}.xml"
  senate_xml_filename = "daylord#{date}.xml"
  new_reps_xml_path = "#{conf.xml_path}/scrapedxml/debates/#{reps_xml_filename}"
  new_senate_xml_path = "#{conf.xml_path}/scrapedxml/lordspages/#{senate_xml_filename}"
  ref_reps_xml_path = "#{File.dirname(__FILE__)}/../../ref/#{reps_xml_filename}"
  ref_senate_xml_path = "#{File.dirname(__FILE__)}/../../ref/#{senate_xml_filename}"
  parser.parse_date_house(date, new_reps_xml_path, House.representatives)
  compare_xml(ref_reps_xml_path, new_reps_xml_path)
  parser.parse_date_house(date, new_senate_xml_path, House.senate)
  compare_xml(ref_senate_xml_path, new_senate_xml_path)  
end

class Array
  def randomly_permute
    temp = clone
    result = []
    (1..size).each do
      i = rand(temp.size)
      result << temp[i]
      temp.delete_at(i)
    end
    result
  end
end

# Randomly permute array. This means that we will cover a much broader range of dates quickly
srand(42)
dates = (from_date..to_date).to_a.randomly_permute

test_first.each do |date|
  # Moves date to the beginning of the array
  dates.delete(date)
  dates.unshift(date)
end

skip_dates.each { |date| dates.delete(date) }

count = skip
time0 = Time.new
dates[skip..-1].each do |date|
  test_date(date, conf, parser, count)
  count = count + 1
  puts "Regression test progress: Done #{count}/#{dates.size}"
  seconds_left = ((Time.new - time0) / (count - skip) * (dates.size - count)).to_i
  
  minutes_left = (seconds_left / 60).to_i
  seconds_left = seconds_left - 60 * minutes_left
  
  hours_left = (minutes_left / 60).to_i
  minutes_left = minutes_left - 60 * hours_left
  
  if hours_left > 0
    puts "Estimated time left to completion: #{hours_left} hours #{minutes_left} mins"
  else
    puts "Estimated time left to completion: #{minutes_left} mins #{seconds_left} secs"
  end
end

puts "Regression tests all passed!"
