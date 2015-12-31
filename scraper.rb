require 'scraperwiki'
=begin
ScraperWiki.sqliteexecute('DROP TABLE IF EXISTS swvariables');
ScraperWiki.sqliteexecute("DELETE FROM lobbyist_firms where abn like '% %'");
ScraperWiki.sqliteexecute("DELETE FROM lobbyists where lobbyist_firm_abn like '% %'");
ScraperWiki.sqliteexecute("DELETE FROM lobbyist_firm_owners where lobbyist_firm_abn like '% %'");
ScraperWiki.sqliteexecute("DELETE FROM lobbyist_clients where lobbyist_firm_abn like '% %'");
=end

require 'yaml'
require 'openssl'
class Array
  def to_yaml_style
    :inline
  end
end
require 'net/https'
require 'uri'

html = ''#open("LobbyExport.html")
uri = URI.parse("http://www.lobbyists.elections.nsw.gov.au")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
http.start {
  http.request_get("/LobbyExportXLS") {|res|
    html = res.body
  }
}

# Next we use Nokogiri to extract the values from the HTML source.

require 'nokogiri'
page = Nokogiri::HTML(html)
headers = page.search('th').map { |a| a.text }
entityname = ""

employees = []
clients = []
owners = []
lobbyist_firm = {}

for tr in page.at('tbody').search('tr')
  #thanks http://ponderer.org/download/xpath/ and http://www.zvon.org/xxl/XPathTutorial/Output/
  values = headers.zip(tr.search('td').map { |a| a.text })
  row_data = {}
  for value in values
    row_data[value[0]] = value[1]
  end
  #puts row_data

  if entityname != row_data['Entity Name'] and entityname != ''
    puts entityname
    #save last
    ScraperWiki.save(["name", "lobbyist_firm_abn"], employees, "lobbyists")
    ScraperWiki.save(["name", "lobbyist_firm_abn"], clients, "lobbyist_clients")
    ScraperWiki.save(["name", "lobbyist_firm_abn"], owners, "lobbyist_firm_owners")
    ScraperWiki.save(["business_name", "abn"], lobbyist_firm, "lobbyist_firms")

    # reset for next lobbyist
    employees = []
    clients = []
    owners = []
    lobbyist_firm = {}
  end
  entityname = row_data['Entity Name']

  companyABN = row_data['ABN'].gsub(' ','').strip()
  companyName = row_data['Entity Name'].strip()
  lobbyist_firm["business_name"] = companyName.strip()
  lobbyist_firm["trading_name"] = row_data['Trading Name'].strip()
  lobbyist_firm["abn"] = companyABN.gsub(' ','').strip()
  lobbyist_firm["status"] = row_data['Status']
  lobbyist_firm["registration_begins"] = row_data["Registration Begins"]
  lobbyist_firm["registration_ends"] = row_data["Registration Ends"]
  if row_data["Contact Type"] == "Client"
    clients << {"lobbyist_firm_name" => lobbyist_firm["business_name"], "lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => row_data["Contact Name"]}
  elsif row_data["Contact Type"] == "Employee"
    employees << {"lobbyist_firm_name" => lobbyist_firm["business_name"], "lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => row_data["Contact Name"]}
  elsif row_data["Contact Type"] == "Owner"
    owners << {"lobbyist_firm_name" => lobbyist_firm["business_name"], "lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => row_data["Contact Name"]}
  else
    puts "error unknown contact type: "+data.to_yaml
  end
end

ScraperWiki.save(["name", "lobbyist_firm_abn"], employees, "lobbyists")
ScraperWiki.save(["name", "lobbyist_firm_abn"], clients, "lobbyist_clients")
ScraperWiki.save(["name", "lobbyist_firm_abn"], owners, "lobbyist_firm_owners")
ScraperWiki.save(["business_name", "abn"], lobbyist_firm, "lobbyist_firms")