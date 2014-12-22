require 'rubygems'
require 'scraperwiki'
require 'open-uri'
base_url = "http://www.lobbyists.elections.nsw.gov.au/"
listing = ScraperWiki.scrape("http://www.lobbyists.elections.nsw.gov.au/whoisontheregister")

# Next we use Nokogiri to extract the values from the HTML source.

require 'nokogiri'
require 'hpricot'
page = Hpricot(listing)

urls = page.search('table.list').search('a').map {|a|
  if a.attributes['href'].include? 'Whois'
    a.attributes['href']
  end}.compact

# resume from the last incomplete url if the scraper was terminated
resumeFromHere = false
last_url = ScraperWiki.get_var("last_url", "")
if last_url == "" then resumeFromHere = true end

urls.each do |url|

  if url.to_s == last_url or last_url == "" then resumeFromHere = true end
  if resumeFromHere
    ScraperWiki.save_var("last_url", url.to_s)
    puts "Downloading #{url}" 
    begin
      lobbyhtml = ScraperWiki.scrape("#{base_url}#{url}")
      lobbypage = Nokogiri::HTML(lobbyhtml)
  
      #thanks http://ponderer.org/download/xpath/ and http://www.zvon.org/xxl/XPathTutorial/Output/
      employees = []
      clients = []
      owners = []
      lobbyist_firm = {}
  
      companyABN=lobbypage.xpath('//span[@id="j_id0:j_id8:j_id11:j_id17:ABN"]/a/text()')
      companyName=lobbypage.xpath('//span[@id="j_id0:j_id8:j_id11:j_id14:businessEntityName"]/text()').first.to_s.gsub(/&amp;/, '&')
      tradingName=lobbypage.xpath('//span[@id="j_id0:j_id8:j_id11:j_id20:tradingName"]/text()').first.to_s.gsub(/&amp;/, '&')
      lobbyist_firm["business_name"] = companyName.to_s
      lobbyist_firm["trading_name"] = tradingName.to_s
      lobbyist_firm["abn"] =  companyABN.to_s
      lobbypage.xpath('//span[@id="j_id0:j_id8:j_id11:j_id32:owners"]/text()').each do |owner|
        ownerNames = owner.content.gsub(/\u00a0/, '').strip.split(',')
        for ownerName in ownerNames
          if ownerName.empty? == false and ownerName.class != 'binary'
              owners << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => ownerName.strip }

          end
        end
      end
      lobbypage.xpath('//tbody[@id="j_id0:j_id43:0:j_id44:j_id46:tb"]/tr').each do |client|
        clientName = client.content.gsub(/\u00a0/, '').strip
        if clientName.empty? == false and clientName.class != 'binary'
            clients << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => clientName }
        end
      end
      lobbypage.xpath('//tbody[@id="j_id0:j_id34:0:j_id35:j_id37:tb"]/tr').each do |employee|
        employeeName = employee.search('td').first.content.gsub(/\u00a0/, '').gsub("  ", " ").strip
        employeePosition = employee.search('td').last.content.gsub(/\u00a0/, '').gsub("  ", " ").strip

        if employeeName.empty? == false and employeeName.class != 'binary'
            employees << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => employeeName, "position" => employeePosition}
        end
      end 
      lobbyist_firm["last_updated"] = lobbypage.xpath('//span[@id="j_id0:j_id8:j_id11:j_id23:detailsLastUpdated"]/text()').to_s

     ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=employees, table_name="lobbyists")
     ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=clients, table_name="lobbyist_clients")
     ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=owners, table_name="lobbyist_firm_owners")
     ScraperWiki.save(unique_keys=["business_name","abn"],data=lobbyist_firm, table_name="lobbyist_firms")
    rescue Timeout::Error => e
      print "Timeout on #{url}"
    end
  else
    print "Skipping #{url}"
  end
end
ScraperWiki.save_var("last_url", "")
