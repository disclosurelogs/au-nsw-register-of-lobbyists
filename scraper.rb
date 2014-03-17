require 'rubygems'
require 'scraperwiki'
require 'pdf-reader'   
require 'open-uri'



html = ScraperWiki.scrape("http://www.dpc.nsw.gov.au/programs_and_services/lobbyist_register/who_is_on_register")

# Next we use Nokogiri to extract the values from the HTML source.

require 'nokogiri'
page = Nokogiri::HTML(html)

urls = page.at('table.lobbyist').search('a').map {|a| a.attributes['href']}

# resume from the last incomplete url if the scraper was terminated
resumeFromHere = false
last_url = ScraperWiki.get_var("last_url", "")
if last_url == "" then resumeFromHere = true end

urls.each do |url|

  if url.to_s == last_url or last_url == "" then resumeFromHere = true end
  if resumeFromHere
    print "Fetching #{url}"
    ScraperWiki.save_var("last_url", url.to_s)
  
    lines = []
    employees = []
    clients = []
    owners = []
    lobbyist_firm = {}
    #######  Instantiate the receiver and the reader
    lineno = 0
    io     = open(url)
    reader = PDF::Reader.new(io)
    reader.pages.each do |page|
     page.text.each_line do |line|
      line = line.strip()
      lineno = lineno + 1
      case line
       when "", "View Lobbyist Details", "Lobbyist Details"
       when /(.*)Details last updated\:(.*)/
           #special case
           lineparts = line.split("Details last updated\:")
           if lineparts.length == 2
               lobbyist_firm["last_updated"] = lineparts[1]
           end
       when /:( |)/, "Client Details", "Owner Details", "Details of all persons or employees who conduct lobbying activities", "Details last updated:"
         #puts "Loading header: #{line}"
         lines << line
       else
         #puts "Loading line: #{line}"
         lines[-1] += " " + line
      end
     end
   end
     in_employees = false
     in_clients = false
     in_owners = false

     name_next = false     
     position_next = false  

     lines.each do |line|
       line = line.strip
       #puts "Processing line: #{line}"
       case line
       when /^Business Entity Name: (.*)/
         lobbyist_firm["business_name"] = $~[1].strip
         puts "Processing records for #{lobbyist_firm['business_name']} #{url}"
       when /^ABN: (.*)/
         lobbyist_firm["abn"] = $~[1].to_s.strip.delete(' ').delete('.').to_i
       when /^ACN: (.*)/
         lobbyist_firm["abn"] = $~[1].strip # not strictly true but unique identifier
       when /^Trading Name: (.*)/
         if $~[1].strip != nil then
           lobbyist_firm["trading_name"] = $~[1].strip
         end
       when "Trading Name:"
         puts "Empty trading name in #{lobbyist_firm['business_name']} #{lobbyist_firm['abn']}, Line =  #{line}"
       when "Details of all persons or employees who conduct lobbying activities", 'Details of all persons or employees who conduct lobbying activities Na'
         in_employees = true
         in_clients = false
         in_owners = false
       when "Client Details"
         in_employees = false
         in_clients = true
         in_owners = false
       when "Owner Details"
         in_employees = false
         in_clients = false
         in_owners = true
       when /^Name: (.*)/
         name = { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => $~[1].strip }
         if in_employees
           employees << name
         elsif in_clients
           clients << name
         elsif in_owners
           owners << name
         else
           raise "Name in an unexpected place '#{line}' #{lineno}"
         end
       when /^Position: (.*)/
         if in_employees
           employees.last["position"] = $~[1].strip
         else
           raise "Position in an unexpected place '#{line}' #{lineno}"
         end
       when /^(Details last up|)dated: (.*)/
         lobbyist["last_updated"] = $~[1].strip      
       when /^including: (.*)/ # special case for some lobbying consortium
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"The Australian Institute of Architects"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"Consult Australia"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"CPA Australia"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"Engineers Australia"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"The Institute of Chartered Accountants in Australia"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"The National Institute of Accountants"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"Professions Australia"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"Deloitte"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"Ernst & Young"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"KPMG"}
         lobbyist["clients"] << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" =>"PricewaterhouseCoopers"}
       when /Owner Details Adelaide/,/Please see the following page for owner detail/
           break; #KPMG have pages and pages of owners
       when /Name:/
           name_next = true
       when /Position:/
           position_next = true
       else
          if name_next and line.strip != "Na"
            name = { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => line.strip }
            if in_employees
               employees << name
               name_next = false
            elsif in_clients
               clients << name
               name_next = false
            elsif in_owners
               owners << name
               name_next = false
            else
              raise "Name in an unexpected place '#{line}' #{lineno}"
            end
          end
          if position_next
            if in_employees
              employees.last["position"] = $~[1].strip
              position_next = false
            else
              raise "Position in an unexpected place '#{line}' #{lineno}"
            end
          end
          if line == "Pegasus: Riding for the Disabled"
              name = name = { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => line.strip }
              clients << name
              name_next = false
          else 
             raise "Don't know what to do with: '#{line}' #{lineno}"  
          end
           
       end
     end 
    
     ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=employees, table_name="lobbyists")
     ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=clients, table_name="lobbyist_clients")
     ScraperWiki.save(unique_keys=["name","lobbyist_firm_abn"],data=owners, table_name="lobbyist_firm_owners")
     ScraperWiki.save(unique_keys=["business_name","abn"],data=lobbyist_firm, table_name="lobbyist_firms")
  else
    print "Skipping #{url}"
  end
end
ScraperWiki.save_var("last_url", "")
