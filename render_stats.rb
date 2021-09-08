require 'json'
require 'pp'
require 'cgi'
require 'date'

def html name, text = nil, **attrs, &contents
	attrs_str = attrs.select{|k,v| v}.map{|k,v| " #{CGI.escapeHTML k.to_s}=\"#{CGI.escapeHTML v.to_s}\"" }.join ''
	s = ''
	s += "<#{CGI.escapeHTML name}#{attrs_str}>" if name
	s += CGI.escapeHTML text.to_s if text
	s += contents.call.to_s if contents
	s += "</#{CGI.escapeHTML name}>" if name
	return s
end

def percent a, b
	return '' if b === 0
	return "#{(a.to_f/b*100).round(1)}%"
end

month = ARGV[0] || nil
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

if month
	range = Date.strptime(month, '%Y-%m').upto( Date.strptime(month, '%Y-%m').next_month.prev_day )
else
	range = Date.today.prev_day(30).upto(Date.today).select{|d| d >= Date.strptime(oldest_rev) }
end
range.reverse_each do |day|
	headers << day.iso8601
	database[:sites].each do |site, data|
		rows[site] << {
			total: data[:revisions].values.select{|r| r[:timestamp].start_with? day.iso8601 }.length,
			suspicious: data[:revisions].values.select{|r| r[:timestamp].start_with? day.iso8601 }.count{|r| r[:suspicious] }
		}
	end
end

if month
	prev_month = Date.strptime(month, '%Y-%m').prev_month
	next_month = Date.strptime(month, '%Y-%m').next_month
	puts html('a', 'Previous', href: "dtstats-#{prev_month.strftime('%Y-%m')}.html")
	puts '•'
	puts html('a', 'Next', href: "dtstats-#{next_month.strftime('%Y-%m')}.html")
else
	prev_month = Date.today.prev_month
	puts html('a', 'Previous', href: "dtstats-#{prev_month.strftime('%Y-%m')}.html")
end

puts html('p', "Choose rows:")
row_info = [
	['sus', 'sus', true],
	['good', 'good', false],
	['total', 'total', true],
	['suspc', 'sus%', false],
]
row_info.each do |(rowclass, rowlabel, active)|
	puts html('style', media: active ? 'not all' : 'all'){ "tr.#{rowclass} > *:not([rowspan]) { display: none; }" }
	onchange = "this.parentNode.previousElementSibling.media = this.checked ? 'not all' : 'all';"
	puts html('label'){
		html('input', type: 'checkbox', checked: active, onchange: onchange) + ' ' +
		html(nil, rowlabel)
	}
end

puts '<table class="wikitable statistics">'
puts '<tr>'
puts html('th', "Site", colspan: 2)
puts html('th', month || "Last 30 days", class: 'summary')
headers.each{|h| puts html('th'){ html 'a', h, href: "dtcheck-#{h}.html" } }
puts '</tr>'

out = []
rows.each do |site, data|
	suspicious = data.map{|d| d[:suspicious] }.inject(:+)
	total = data.map{|d| d[:total] }.inject(:+)

	out << '<tr class="sus">'
	out << html('th', site, rowspan: 4)
	out << html('th', "sus")
	out << html('td', suspicious)
	data.each{|d| out << html('td', d[:suspicious]) }
	out << '</tr>'
	out << '<tr class="good">'
	out << html('th', "good")
	out << html('td', total - suspicious)
	data.each{|d| out << html('td', d[:total] - d[:suspicious]) }
	out << '</tr>'
	out << '<tr class="total">'
	out << html('th', "total")
	out << html('td', total)
	data.each{|d| out << html('td', d[:total]) }
	out << '</tr>'
	out << '<tr class="suspc">'
	out << html('th', "sus%")
	out << html('td', percent(suspicious, total) )
	data.each{|d| out << html('td', percent(d[:suspicious], d[:total] )) }
	out << '</tr>'
end

suspicious = headers.length.times.map{|i| rows.map{|site, r| r[i][:suspicious] }.inject(:+) }
total = headers.length.times.map{|i| rows.map{|site, r| r[i][:total] }.inject(:+) }

puts '<tr class="sus">'
puts html('th', "All sites", rowspan: 4, class: 'summary')
puts html('th', "sus", class: 'summary')
puts html('td', suspicious.inject(:+), class: 'summary')
suspicious.each{|s| puts html('td', s) }
puts '</tr>'
puts '<tr class="good">'
puts html('th', "good", class: 'summary')
puts html('td', total.inject(:+) - suspicious.inject(:+), class: 'summary')
suspicious.zip(total).each{|s, t| puts html('td', t - s) }
puts '</tr>'
puts '<tr class="total">'
puts html('th', "total", class: 'summary')
puts html('td', total.inject(:+), class: 'summary')
total.each{|s| puts html('td', s) }
puts '</tr>'
puts '<tr class="suspc">'
puts html('th', "sus%", class: 'summary')
puts html('td', percent(suspicious.inject(:+), total.inject(:+)), class: 'summary')
suspicious.zip(total).each{|s, t| puts html('td', percent(s, t)) }
puts '</tr>'

puts out.join("\n")

puts '</table>'

puts html('p', "Generated at #{database[:last_updated]} in #{(database[:last_updated_duration]).ceil} seconds.")
puts html('p'){ html('a', 'Source code', href: "https://github.com/MatmaRex/dtcheck") }
