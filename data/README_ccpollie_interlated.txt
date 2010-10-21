INSTALL

1. need to drop and recreate member_id column to add auto_increment. Should be system wide key reall.

alter table member drop column member_id;
alter table member add column member_id bigint not null auto_increment key;

2. Gems

gem install dbi
gem install dbd-mysql

3. Run 



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

SELECT member_id, house, title, first_name, last_name, constituency, party, entered_house, left_house, entered_reason, left_reason, member_id FROM member WHERE member_id = '927' ORDER BY left_house DESC, house


Querying

http://openoz.scmedia.net.au/mp/openoz_memberemail.php?postcode=2038

SELECT mem.member_id, mem.house, mem.title, mem.first_name, mem.last_name, mem.constituency, mem.party, mem.entered_house, mem.left_house, mem.entered_reason, mem.left_reason, mem.member_id, info.data_value as email 
FROM member mem INNER JOIN memberinfo info ON mem.member_id = info.member_id
WHERE mem.member_id = '927'  AND info.data_key = 'email'
ORDER BY mem.left_house DESC, mem.house;
