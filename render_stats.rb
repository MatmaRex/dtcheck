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

database = JSON.parse File.read('database.json'), symbolize_names: true

puts '<meta charset="utf-8">'
puts '<link rel="stylesheet" type="text/css" href="styles.css">'
puts '<link rel="stylesheet" type="text/css" href="styles-mw.css">'

puts html('style', '.summary { font-weight: bold; background: #c6cbd1 !important; }')
puts html('style', <<STYLE)
@supports (writing-mode: sideways-lr) {
	th a {
		white-space: nowrap;
		writing-mode: sideways-lr;
		padding: 0.2em 0;
	}
}
@supports (writing-mode: vertical-rl) and (not (writing-mode: sideways-lr)) {
	th a {
		white-space: nowrap;
		writing-mode: vertical-rl;
		padding: 0.2em 0;
		transform: rotate(180deg);
	}
}
STYLE

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

puts html('p', "Choose rows:")
row_info = {
	'sus' => true,
	'good' => false,
	'total' => true,
	'suspc' => false,
}
row_info.each do |rowtype, active|
	puts html('style', media: active ? 'not all' : 'all'){ "tr.#{rowtype} > *:not([rowspan]) { display: none; }" }
	onchange = "this.parentNode.previousElementSibling.media = this.checked ? 'not all' : 'all';"
	puts html('label'){
		html('input', type: 'checkbox', checked: active, onchange: onchange) + ' ' +
		html(nil, rowtype)
	}
end

puts '<table class="wikitable">'
puts '<tr>'
puts html('th', "Site", colspan: 2)
headers.each{|h| puts html('th'){ html 'a', h, href: "dtcheck-#{h}.html" } }
puts html('th', "All days", class: 'summary')
puts '</tr>'

rows.each do |site, data|
	suspicious = data.map{|d| d[:suspicious] }.inject(:+)
	total = data.map{|d| d[:total] }.inject(:+)

	puts '<tr class="sus">'
	puts html('th', site, rowspan: 4)
	puts html('th', "sus")
	data.each{|d| puts html('td', d[:suspicious]) }
	puts html('td', suspicious)
	puts '</tr>'
	puts '<tr class="good">'
	puts html('th', "good")
	data.each{|d| puts html('td', d[:total] - d[:suspicious]) }
	puts html('td', total - suspicious)
	puts '</tr>'
	puts '<tr class="total">'
	puts html('th', "total")
	data.each{|d| puts html('td', d[:total]) }
	puts html('td', total)
	puts '</tr>'
	puts '<tr class="suspc">'
	puts html('th', "suspc")
	data.each{|d| puts html('td', percent(d[:suspicious], d[:total] )) }
	puts html('td', percent(suspicious, total) )
	puts '</tr>'
end

suspicious = headers.length.times.map{|i| rows.map{|site, r| r[i][:suspicious] }.inject(:+) }
total = headers.length.times.map{|i| rows.map{|site, r| r[i][:total] }.inject(:+) }

puts '<tr class="sus">'
puts html('th', "All sites", rowspan: 4, class: 'summary')
puts html('th', "sus", class: 'summary')
suspicious.each{|s| puts html('td', s) }
puts html('td', suspicious.inject(:+), class: 'summary')
puts '</tr>'
puts '<tr class="good">'
puts html('th', "good", class: 'summary')
suspicious.zip(total).each{|s, t| puts html('td', t - s) }
puts html('td', total.inject(:+) - suspicious.inject(:+), class: 'summary')
puts '</tr>'
puts '<tr class="total">'
puts html('th', "total", class: 'summary')
total.each{|s| puts html('td', s) }
puts html('td', total.inject(:+), class: 'summary')
puts '</tr>'
puts '<tr class="suspc">'
puts html('th', "suspc", class: 'summary')
suspicious.zip(total).each{|s, t| puts html('td', percent(s, t)) }
puts html('td', percent(suspicious.inject(:+), total.inject(:+)), class: 'summary')
puts '</tr>'

puts '</table>'

puts html('p', "Generated at #{database[:last_updated]} in #{(database[:last_updated_duration]).ceil} seconds.")
puts html('p'){ html('a', 'Source code', href: "https://github.com/MatmaRex/dtcheck") }
