#!/usr/bin/env ruby

# == Synopsis 
#   Load the postcode and NSW candidate data directly into the database
#
# == Examples
#   Import postcodes from postcodes_2011nsw.csv and candidates from candidates_2011nsw.csv
#
#      ruby ./import_nsw_candidates.rb -p data/postcodes_2011nsw.csv -c data/candidates_2011nsw.csv
#
#   Other examples:
#
#
# == Configuration
# Requires lib/configuration_nsw.rb which loads configuration data from:
# ./openaustralia-parser/lib/configuration.rb
#
# == Description
#
# 1. Remove national postcode data
#   delete from postcode_lookup
# 2. Remove national member data
#   delete from member
# 
#
# == Usage 
#   import_nsw_candidates.rb [options] source_file
#
#   For help use: import_nsw_candidates.rb -h
#
# == Options
#   -p, --postcodes        Postcode CSV file
#   -c, --candidates       Candidates CSV file
#
#
# == Author
#   John Robens
#
# == Copyright
#   Copyright (c) 2011 Interlated Pty Ltd. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php
#
# http://blog.toddwerth.com/entries/show/5

$:.unshift "#{File.dirname(__FILE__)}/lib"

# in `require': no such file to load -- mysql (LoadError)
require 'rubygems'
require 'active_support/core_ext'

require 'csv'
require 'mysql'
require 'configuration_nsw'
require 'people'

require 'optparse'
require 'rdoc/usage'
require 'ostruct'

class NswParser
  VERSION = '0.0.1'
  
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    
    # Set defaults
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
    
    @options.postcodes = ""
    @options.candidates = ""
    
  end

  # Parse options, check arguments, then process the command
  def run
        
    if parsed_options? && arguments_valid?
      
      output_options if @options.verbose # [Optional]
            
      process_arguments
      
      # run as import_nsw_candidates -p "data/postcodes_2010nsw.csv" -c
      postcode_parser = ParsePostcodeNSW.new()
      postcode_parser.parse(@options.postcodes)
      
      candidate_parser = ParseCandidateNSW.new()
      candidate_parser.parse(@options.candidates)
      
    else
      output_usage
    end
      
  end
  
  protected
  def parsed_options?
      
    # Specify options
    opts = OptionParser.new
    opts.on('-v', '--version')    { output_version ; exit 0 }
    opts.on('-h', '--help')       { output_help }
    opts.on('-V', '--verbose')    { @options.verbose = true }
    opts.on('-q', '--quiet')      { @options.quiet = true }
      
    # Non-generic options
    opts.on('-p', '--postcodes STRING', 'Requires a postcodes CSV FILE ')  do |postcodes|
      @options.postcodes = postcodes
    end
        
    opts.on('-c', '--candidates STRING', 'Requires a candidates CSV FILE ') do |candidates|
      @options.candidates = candidates
    end
            
    opts.parse!(@arguments) rescue return false
      
    process_options
    true
  end

  # Performs post-parse processing on options
  def process_options
    @options.verbose = false if @options.quiet
  end
    
  def output_options
    puts "Options:\
    "
      
    @options.marshal_dump.each do |name, val|
      puts "  #{name} = #{val}"
    end
  end

  # True if required arguments were provided
  def arguments_valid?
    # Should be no remaining arguments
    true if @arguments.length == 0
  end
    
  # Setup the arguments
  def process_arguments
    # TO DO - place in local vars, etc
  end
    
  def output_help
    output_version
    RDoc::usage() #exits app
  end
    
  def output_usage
    RDoc::usage('usage') # gets usage from comments above
  end
    
  def output_version
    puts "#{File.basename(__FILE__)} version #{VERSION}"
  end
    
  def process_command
    # TO DO - do whatever this app does
      
    #process_standard_input # [Optional]
  end

  def process_standard_input
    input = @stdin.read
    # TO DO - process input
      
    # [Optional]
    # @stdin.each do |line|
    #  # TO DO - process each line
    #end
  end
end


#end

#
#
# Expects a CSV file of postcode|Electoral District.
#
#
class ParsePostcodeNSW

  def initialize()
    # Configuration for NSW - make sure that this is a different database to the cwth one.
    @conf = ConfigurationNSW.new
  end
  
  def parse(file)
    # Open the CSV file.
    puts "Reading postcode data... #{file}"
    divisions = CSV.readlines(file)
    
    
    db = Mysql.real_connect(@conf.database_host, @conf.database_user, @conf.database_password, @conf.database_name)
    
    
    # Clear out the old data
    puts "clearing postcode_lookup"
    db.query("DELETE FROM postcode_lookup")
    
    sql = "INSERT INTO postcode_lookup (postcode, name) VALUES (?, ?)"
    st = db.prepare(sql)


    divisions.each do |division|
      postcode = division[0]
      electoral_district = division[1]
      
      # Don't worry about skipping the first one - just check to see whether the postcode is numeric
      # Works in AU may not work in other jurisdictions.
      if !is_number?(postcode)
        puts "Rejected #{postcode} from #{postcode},#{electoral_district} as the postcode should be a number."
      elsif !is_not_null?(electoral_district)
        puts "Rejected #{electoral_district} from #{postcode},#{electoral_district} as the electoral district should not be null."
      else
        st.execute(postcode, electoral_district)
      end
    end
    st.close
    
    #values = divisions.map {|row| "('#{row[0]}', '#{quote_string(row[1])}')" }.join(',')
    #db.query("INSERT INTO postcode_lookup (postcode, name) VALUES #{values}")
  end

  def quote_string(s)
    s.gsub(/\\/, '\&\&').gsub(/'/, "''") # ' (for ruby-mode)
  end

  def is_number?(i)
    true if Float(i) rescue false
  end

  def is_not_null?(name)
    true unless name.empty? rescue false
  end

end

#
#
# Expects a CSV file of postcode|Electoral District.
#
#
class ParseCandidateNSW

  def initialize()
    # Not actually true, but necessary for them to come out in the postcode lookup
    @entered_reason = "candidate"
    @left_reason = "still_in_office"

    @email_data_key = "email"

    # Configuration for NSW - make sure that this is a different database to the cwth one.
    @conf = ConfigurationNSW.new
    @db = Mysql.real_connect(@conf.database_host, @conf.database_user, @conf.database_password, @conf.database_name)
  end

  def parse(file)
    # Open the CSV file.
    puts "Reading candidate data... #{file}"
    candidates = CSV.readlines(file)
    
    puts "clearing members"
    @db.query("DELETE FROM member")

    puts "clearing memberinfo"
    @db.query("DELETE FROM memberinfo")

    sql = "INSERT INTO member (house, first_name, last_name, constituency, party, entered_house, left_house, entered_reason, left_reason) VALUES (1,?,?,?,?,now(),now(),?, ?)"
    st = @db.prepare(sql)

    id_sql = "SELECT member_id from member where first_name = ? and last_name = ? and constituency = ? and party = ?"
    id_st = @db.prepare(id_sql)

    postcode_sql = "SELECT name FROM postcode_lookup where name = ?"
    postcode_st = @db.prepare(postcode_sql)

    memberinfo_sql = "INSERT INTO memberinfo (member_id,data_key,data_value) VALUES (?,?,?)"
    memberinfo_st = @db.prepare(memberinfo_sql)

    candidates.each do |candidate|
      first_name = candidate[0]
      last_name = candidate[1]
      electoral_district = candidate[2]
      party = candidate[3]
      email = candidate[4]

      # Reject any lines that don't have electoral districts in the postcode table
      if !is_not_null?(email)
        puts "Rejected #{email} from #{first_name},#{last_name},#{electoral_district},#{party} as the email address was blank."
      elsif is_valid_electoral_district?(postcode_st, electoral_district)
        st.execute(first_name, last_name, electoral_district,party,@entered_reason,@left_reason)
        # Store the email in the memberinfo table
        # Probably could have kept the member_id from the insert (?)

        id_st.execute(first_name, last_name, electoral_district, party)
        
        #hopefully only 1
        member_id_row = id_st.fetch
        update_memberinfo(memberinfo_st, member_id_row[0], email)

      else
        puts "Rejected #{electoral_district} from #{first_name},#{last_name},#{electoral_district},#{party} as the electoral district was not found in the postcode table."
      end
    end
    st.close
    id_st.close
    postcode_st.close
    memberinfo_st.close
  end

  def is_not_null?(name)
    true unless name.empty? rescue false
  end

  # Look to see if the district is in the postcode table as a verification.
  def is_valid_electoral_district?(st,district)
    st.execute(district)
    true if st.num_rows() != 0
  end

  # put the email address into the memberinfo table.
  def update_memberinfo(st, member_id, email)
    # No email - should roll back the entire transaction. Check prior.
    st.execute(member_id, @email_data_key, email)
  end
  
end

# Create and run the application
nsw_parser = NswParser.new(ARGV, STDIN)
nsw_parser.run

  