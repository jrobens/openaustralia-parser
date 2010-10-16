INSTALL

1. need to drop and recreate member_id column to add auto_increment. Should be system wide key reall.

alter table member drop column member_id;
alter table member add column member_id bigint not null auto_increment key;

2. Gems

gem install dbi



DESIGN

1. require a list of politicians by postcode with name and email address.

Index of members by electorate:

http://aph.gov.au/house/members/mi-elctr.asp

2. postcodes.rb still works with list of electorates by postcode

Details:

json.php -> postcode_to_constituency  -> select name from postcode_lookup where postcode = "'. mysql_escape_string($postcode).'"

postcode_lookup = postcode|name

MP lookup  openoz/twfy/www/includes/easyparliament/member.php -> SELECT person_id FROM member
                                        WHERE constituency = '" . mysql_escape_string($constituency) . "'
                                        AND left_reason = 'still_in_office

member_id|house|first_name|last_name|constituency|party|entered_house|left_house|entered_reason|left_reason|person_id| title|lastupdate

Still need email address:
Suggest memberinfo

member_id|data_key|data_value|lastupdate

e.g.
12|email|julia.gillard.MP@aph.gov.au|...


    