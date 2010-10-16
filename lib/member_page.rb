# Pull the needed data from a member page.
# member: member_id|house|first_name|last_name|constituency|party|entered_house|left_house|entered_reason|left_reason|person_id| title|lastupdate
# memberinfo : member_id|data_key|data_value|lastupdate

# only doing lower house. You would have to subclass to do both.

# This is not going to replace people who have moved out of office. The query code must select the most recent member
# for any constituency.


# Test cases to write
# 1. insert of existing mp
# 2. insert of email into memberdetails for existing mp
# 3. insert of new mp
# 4. insert of email for new mp
# 5. quotes, ';' etc.
# 6. validate the count of mps


$:.unshift "#{File.dirname(__FILE__)}/lib"

require 'rubygems'
require 'mechanize'

require 'configuration'
#require 'active_support/core_ext'
require 'dbi'
#require 'dbd-mysql'
#require 'mysql'

class MemberPage


  # constant house name.
  HOUSE = "representatives"

  @house = HOUSE
  @first
  @surname
  @constituency
  @title
  @party
  @email

  # We use this xpath string multiple times to find the text
  DETAILS_XPATH = "table:nth-child(3) table tr:nth-child(1) td:nth-child(1)"

  def initialize()
    @mech = Mechanize.new do |agent|
      agent.user_agent_alias = 'Mac Safari'
      agent.set_proxy('localhost', 9999)
    end
  end

  def parse(href, constituency)
    @constituency = constituency

    member_page = @mech.get(href)
    # error checking.

    extract_details(member_page)

    # Everything is good, then persist the data
    persist

  end

  def extract_details(member_page)
    extract_name(member_page)
    extract_title(member_page)
    extract_party(member_page)
    extract_email(member_page)
  end

  # Extract their name - this could have trouble with non-conforming names.
  # <h2>Hon Kate Ellis MP</h2>
  # We should use the honorific too.
  # The index page has a nicer format sur, first
  def extract_name(member_page)
    # Hon Kate Ellis MP
    name_text = member_page.at("h2").text

    name_split = name_text.split()
    name_split.pop
    name_split.shift

    surname = name_split.pop
    firstname = name_split.join(" ")

    @first = firstname
    @surname = surname

  end

  # <strong>Party</strong>: Australian Labor Party
  def extract_title(member_page)
    title_row = member_page.at(DETAILS_XPATH).text
    title_text = title_row.split(/Title: |Party:/).each { |word| word.chomp }[1]
    @title = title_text
  end

  #  <strong>Party</strong>: Australian Labor Party
  def extract_party(member_page)
    party_row = member_page.at(DETAILS_XPATH).text
    party_text = party_row.split(/Party: |Parliament House Contact/).each { |word| word.strip }[1]
    @party = party_text.strip
  end

  # Look for the link starting with mailto:
  def extract_email(member_page)
    member_page.links_with(:href => %r{mailto:*}).each do |link|
      # has to be a good thing Only the first one.
      if (!@email)
        @email = link.text
      end
    end

    # Some of the MPs have a contact form on this page. It might be possible to parse the PDF file at http://www.aph.gov.au/house/members/index.htm#contact with  http://github.com/yob/pdf-reader
    if (@email == 'House of Representatives Web Administrator')
      @email = @first + "." + @surname + '.mp@aph.gov.au'
      puts "Substituted email #{@email}"
    end
  end

  # Save the data in the database
  def persist

    begin
      db = connect_db

      # need person_id?

      # Update or insert pattern. This is not going to replace people if they have gone out of office. Query code must select by date.
      # Key can be first + surname + constituency
      # Installing ri documentation for mysql-2.8.1...
      delete_query = "DELETE FROM member WHERE first_name = ? AND last_name = ? and constituency = ?"
      db.do(delete_query, @first, @surname, @constituency)


      # Could prepare - but I create this whole object each time and don't care about efficiency.
      insert_query = "INSERT INTO member (house, first_name, last_name, constituency, party, left_reason, lastupdate) VALUES (?,?,?,?,?,?,?)"
      sth = db.prepare(insert_query)
      sth.execute(1, @first, @surname, @constituency, @party, 'still_in_office', Date.today)
      last_id = db.func(:insert_id)

      # check the result
      if (!last_id)
        puts "ERROR insert_query #{insert_query} didn't work"
      end

      # Add to memberinfo
      add_member_email(db, last_id)

    rescue DBI::DatabaseError => e
      puts "Error code: #{e.err}"
      puts "Error message: #{e.errstr}"
    ensure
      db.disconnect if db
    end

  end

  def connect_db
    begin
      conf = Configuration.new
      db = DBI.connect("DBI:Mysql:#{conf.database_name}:#{conf.database_host}", conf.database_user, conf.database_password)
      row = db.select_one("SELECT VERSION()")
      puts "Server version: " + row[0]
      return db
    end
  rescue DBI::DatabaseError => e
    puts "Error code: #{e.errno}"
    puts "Error message: #{e.error}"
    puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
  end


  def add_member_email(db, member_id)
    delete_query = "DELETE FROM memberinfo WHERE data_key = 'email' AND data_value = ?"
    delete_result = db.do(delete_query, @email)

    if (!delete_result)
      puts "ERROR Failed to clean up memberinfo"
    end

    insert_query = "INSERT INTO memberinfo (member_id, data_key, data_value) VALUES (?,?,?)"
    insert_result = db.do(insert_query, member_id, 'email', @email)
    if (insert_result != 1)
      puts "ERROR Failed to insert email into memberinfo. #{insert_query}"
    end

  end
end