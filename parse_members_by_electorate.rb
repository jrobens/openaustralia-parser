# Go to the APH site listing the members by electorate. For each electorate update the members first, surname and email address.
#
# Updates member: member_id|house|first_name|last_name|constituency|party|entered_house|left_house|entered_reason|left_reason|person_id| title|lastupdate
# and
# memberinfo : member_id|data_key|data_value|lastupdate
# e.g.
# 12|email|julia.gillard.MP@aph.gov.au|...

$:.unshift "#{File.dirname(__FILE__)}/lib"

require 'rubygems'
require 'mechanize'
require 'configuration'
require 'member_page'

class ParseMembersByElectorate

  conf = Configuration.new

  @limit

  #  http://aph.gov.au/house/members/mi-elctr.asp

  PARENT =  "http://aph.gov.au/house/members/"
  PAGE = "mi-elctr.asp"

  def initialize()
    # Set this to 1 just to debug the first one.
    @limit = 5000    

    @mech = Mechanize.new do |agent|
      agent.user_agent_alias = 'Mac Safari'
      agent.set_proxy('localhost', 9999)
    end
  end

  # Just load the html - has a list of electorates on it.
  def load_page()
    page = @mech.get(PARENT + PAGE)

    # Catch exception - 404 => Net::HTTPNotFound
  end

  # Iterate over all the electorate pages on the site.
  def parse_electorates(page)
    count = 1
    page.links_with(:href => %r{member\.asp*}).each do |link|
      if (count < @limit)
        # Get this page
        member_page = MemberPage.new()
        member_page.parse(PARENT + link.href, link.text)
      end
      count += 1
    end

    # Get the member page
    puts "Found #{count} MPs."

  end
end


member_parser = ParseMembersByElectorate.new()
page = member_parser.load_page()
member_parser.parse_electorates(page)