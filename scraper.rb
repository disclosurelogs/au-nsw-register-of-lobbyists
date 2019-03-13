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
require 'httpclient'
require 'nokogiri'
html = ''
# html = open("LobbyExport.html")
uri = URI.parse("http://lobbyists.elections.nsw.gov.au")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true if uri.scheme == "https" # enable SSL/TLS
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
http.start {
  http.request_get("/whoisontheregister") {|res|
    html = res.body
  }
}


page = Nokogiri::HTML(html)
viewstate = Hash[page.search('#ajax-view-state input').map {|input|
  [input['id'], input['value']]
}]
lobby_pages = page.search('#tableSort2 tbody tr').map {
    |a|
  {"entity_name" => a.children[1].text.strip,
   "onclick" => a.children[1].search('a')[0]['onclick'],
   "abn" => a.children[3].text.strip,
   "business_trading_name" => a.children[5].text.strip
  }
}

employees = []
clients = []
owners = []
lobbyist_firm = {}

for lobby_page in lobby_pages

  clnt = HTTPClient.new
  body = viewstate
  body['AJAXREQUEST'] = '_viewRoot'
  body['j_id0:j_id18'] = 'j_id0:j_id18'
  body['j_id0:j_id18:j_id19'] = 'j_id0:j_id18:j_id19'
  body['selectedLobbyistId'] = lobby_page["onclick"].scan(/showLobbyDetails\('(.*)',/).last
  res = clnt.post('http://lobbyists.elections.nsw.gov.au/whoisontheregister',
                  :header => {"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8"},
                  :body => body
  )
  html = res.body
  puts html
  # html = open("test2.html")
  page = Nokogiri::HTML(html)


  lobbyist_firm["business_name"] = lobby_page['entity_name'].strip()
  puts lobbyist_firm["business_name"]
  lobbyist_firm["trading_name"] = lobby_page['business_trading_name'].strip()
  lobbyist_firm["abn"] = lobby_page['abn'].gsub(' ', '').strip()

  # lobtab = page.search('.tableSort').first.at('tbody').children

  # lobbyist_firm["status"] = lobtab[9].at('td').children[1].text.strip
  # lobbyist_firm["last_updated"] = lobtab[5].at('td').children[1].text.strip

  if page.at('#lobTab2')
    lobtab_client = page.at('#lobTab2').at('tbody').search('tr')
    for client in lobtab_client
      client_data = client.search("td")
      clients << {"lobbyist_firm_name" => lobbyist_firm["business_name"], "lobbyist_firm_abn" => lobbyist_firm["abn"],
                  "name" => client_data[0].text, "abn" => client_data[1].text.gsub(' ', '').strip(), "added_date" => client_data[3].text}
    end
  end

  if page.at('#lobTab3')
    lobtab_employee = page.at('#lobTab3').at('tbody').search('tr')
    for employee in lobtab_employee
      employee_data = employee.search("td")
      employees << {"lobbyist_firm_name" => lobbyist_firm["business_name"], "lobbyist_firm_abn" => lobbyist_firm["abn"],
                    "name" => employee_data[0].text, "position" => employee_data[1].text, "added_date" => employee_data[3].text}
    end
  end

  if page.at('#lobTab4')
    lobtab_owner = page.at('#lobTab4').at('tbody').search('tr')
    for owner in lobtab_owner
      owner_data = owner.search("td")
      owners << {"lobbyist_firm_name" => lobbyist_firm["business_name"], "lobbyist_firm_abn" => lobbyist_firm["abn"],
                 "name" => owner_data[0].text, "added_date" => owner_data[2].text}
    end
  end


  # save results
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
