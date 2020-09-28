require 'json'
require 'pp'
require 'cgi'
require 'date'

def html name, text = nil, **attrs, &contents
	attrs_str = attrs.map{|k,v| " #{CGI.escapeHTML k.to_s}=\"#{CGI.escapeHTML v.to_s}\"" }.join ''
	s = ''
	s += "<#{CGI.escapeHTML name}#{attrs_str}>" if name
	s += CGI.escapeHTML text.to_s if text
	s += contents.call.to_s if contents
	s += "</#{CGI.escapeHTML name}>" if name
	return s
end

database = JSON.parse File.read('database.json'), symbolize_names: true

puts '<meta charset="utf-8">'
puts '<link rel="stylesheet" type="text/css" href="styles.css">'
puts '<link rel="stylesheet" type="text/css" href="styles-mw.css">'

title = "Reply tool check statistics"
puts html('title', title)
puts html('h1', title)

headers = []
rows = database[:sites].keys.map{|site| [site, []] }.to_h


oldest_rev = database[:sites].values.map{|data| data[:revisions].values }.inject(:+).map{|a| a[:timestamp] }.min

Date.strptime(oldest_rev).upto(Date.today) do |day|
	headers << day.iso8601
	database[:sites].each do |site, data|
		rows[site] << {
			total: data[:revisions].values.select{|r| r[:timestamp].start_with? day.iso8601 }.length,
			suspicious: data[:revisions].values.select{|r| r[:timestamp].start_with? day.iso8601 }.count{|r| r[:suspicious] }
		}
	end
end


puts '<table class="wikitable">'
puts '<tr>'
puts html('th', "Site", colspan: 2)
headers.each{|h| puts html('th'){ html 'a', h, href: "dtcheck-#{h}.html" } }
puts html('th', "All days", class: 'summary')
puts '</tr>'

rows.each do |site, data|
	puts '<tr>'
	puts html('th', site, rowspan: 2)
	puts html('th', "sus")
	data.each{|d| puts html('td', d[:suspicious]) }
	puts html('td', data.map{|d| d[:suspicious] }.inject(:+))
	puts '</tr>'
	puts '<tr>'
	puts html('th', "total")
	data.each{|d| puts html('td', d[:total]) }
	puts html('td', data.map{|d| d[:total] }.inject(:+))
	puts '</tr>'
end

puts '<tr>'
puts html('th', "All sites", rowspan: 2, class: 'summary')
puts html('th', "sus", class: 'summary')
headers.length.times{|i| puts html('td', rows.map{|site, r| r[i][:suspicious] }.inject(:+) ) }
puts html('td', headers.length.times.map{|i| rows.map{|site, r| r[i][:suspicious] }.inject(:+) }.inject(:+), class: 'summary')
puts '</tr>'
puts '<tr>'
puts html('th', "total", class: 'summary')
headers.length.times{|i| puts html('td', rows.map{|site, r| r[i][:total] }.inject(:+) ) }
puts html('td', headers.length.times.map{|i| rows.map{|site, r| r[i][:total] }.inject(:+) }.inject(:+), class: 'summary')
puts '</tr>'

puts '</table>'

puts html('p', "Generated at #{database[:last_updated]} in #{(database[:last_updated_duration]).ceil} seconds.")
puts html('p'){ html('a', 'Source code', href: "https://github.com/MatmaRex/dtcheck") }

puts html('style', '.summary { font-weight: bold; background: #c6cbd1 !important; }')
puts html('style', 'th { white-space: nowrap; }')
