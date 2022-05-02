require_relative 'vendor/bundle/bundler/setup'
require 'json'
require 'pp'
require 'cgi'
require 'date'
require 'sequel'

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

month = ARGV[0] && ARGV[0] != '' ? ARGV[0] : nil
fields = (ARGV[1] || 'sus,total').split(',')
sort_date = ARGV[2] && ARGV[2] != '' ? ARGV[2] : nil
database = Sequel.sqlite 'database.sqlite'

puts '<meta charset="utf-8">'
puts '<link rel="stylesheet" type="text/css" href="styles.css">'
puts '<link rel="stylesheet" type="text/css" href="styles-mw.css">'

title = "Reply tool check statistics"
puts html('title', title)
puts html('h1', title)

row_headers = database.fetch("select distinct site from revisions").map(:site)
oldest_rev = database.fetch("select min(timestamp) from revisions").get

if month
	range = Date.strptime(month, '%Y-%m').upto( Date.strptime(month, '%Y-%m').next_month.prev_day )
else
	range = Date.today.prev_day(30).upto(Date.today).select{|d| d >= Date.strptime(oldest_rev) }
end
headers = range.map{|day| day.iso8601 }.reverse

rows = row_headers.map{|site| [ site, headers.map{ {
	total: 0,
	suspicious: 0,
} } ] }.to_h

database
	.fetch("
		select site, date(timestamp) as day, count(*) as total, sum(suspicious) as suspicious
		from revisions
		where site in #{database.literal row_headers}
		and date(timestamp) in #{database.literal headers}
		group by site, date(timestamp)
	")
	.each do |data|
		rows[ data[:site] ][ headers.index(data[:day]) ][:total] = data[:total]
		rows[ data[:site] ][ headers.index(data[:day]) ][:suspicious] = data[:suspicious] || 0
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

row_info = [
	['sus', 'sus'],
	['good', 'good'],
	['total', 'total'],
	['suspc', 'sus%'],
]
puts html('form', action: 'dtstats.rb') {
	html('p', "Choose rows: ") {
		row_info.map {|(rowclass, rowlabel)|
			active = fields.include? rowclass
			html('label'){
				html('input', type: 'checkbox', checked: active, name: 'field', value: rowclass) + ' ' +
				html(nil, rowlabel)
			}
		}.join ' '
	} +
	( month ? html('input', type: 'hidden', name: 'month', value: month) : '' ) +
	html('p', "Sort by: ") {
		html('select', name: 'sort_date') {
			html('option', month || "Last 30 days", value: '', selected: sort_date == nil ) +
			headers.map{|h| html('option', h, value: h, selected: sort_date == h ) }.join('')
		}
	} +
	html('input', type: 'submit')
}

puts '<table class="wikitable statistics">'
puts '<tr>'
puts html('th', "Site", colspan: 2)
puts html('th', month || "Last 30 days", class: 'summary')
headers.each{|h| puts html('th'){ html 'a', h, href: "dtcheck-#{h}.html" } }
puts '</tr>'

sort_index = sort_date ? headers.index(sort_date) : nil
rows = Hash[ rows.sort_by{|site, data|
	sort_index ? data[sort_index][:total] : data.map{|d| d[:total] }.inject(:+)
}.reverse ]

out = []
rows.each do |site, data|
	suspicious = data.map{|d| d[:suspicious] }.inject(:+)
	total = data.map{|d| d[:total] }.inject(:+)

	header = html('th', site, rowspan: fields.length)
	if fields.include? 'sus'
		out << '<tr>'
		out << header if header; header = nil
		out << html('th', "sus")
		out << html('td', suspicious)
		data.each{|d| out << html('td', d[:suspicious]) }
		out << '</tr>'
	end
	if fields.include? 'good'
		out << '<tr>'
		out << header if header; header = nil
		out << html('th', "good")
		out << html('td', total - suspicious)
		data.each{|d| out << html('td', d[:total] - d[:suspicious]) }
		out << '</tr>'
	end
	if fields.include? 'total'
		out << '<tr>'
		out << header if header; header = nil
		out << html('th', "total")
		out << html('td', total)
		data.each{|d| out << html('td', d[:total]) }
		out << '</tr>'
	end
	if fields.include? 'suspc'
		out << '<tr>'
		out << header if header; header = nil
		out << html('th', "sus%")
		out << html('td', percent(suspicious, total) )
		data.each{|d| out << html('td', percent(d[:suspicious], d[:total] )) }
		out << '</tr>'
	end
end

suspicious = headers.length.times.map{|i| rows.map{|site, r| r[i][:suspicious] }.inject(:+) }
total = headers.length.times.map{|i| rows.map{|site, r| r[i][:total] }.inject(:+) }

header = html('th', "All sites", rowspan: fields.length, class: 'summary')
if fields.include? 'sus'
	puts '<tr>'
	puts header if header; header = nil
	puts html('th', "sus", class: 'summary')
	puts html('td', suspicious.inject(:+), class: 'summary')
	suspicious.each{|s| puts html('td', s) }
	puts '</tr>'
end
if fields.include? 'good'
	puts '<tr>'
	puts header if header; header = nil
	puts html('th', "good", class: 'summary')
	puts html('td', total.inject(:+) - suspicious.inject(:+), class: 'summary')
	suspicious.zip(total).each{|s, t| puts html('td', t - s) }
	puts '</tr>'
end
if fields.include? 'total'
	puts '<tr>'
	puts header if header; header = nil
	puts html('th', "total", class: 'summary')
	puts html('td', total.inject(:+), class: 'summary')
	total.each{|s| puts html('td', s) }
	puts '</tr>'
end
if fields.include? 'suspc'
	puts '<tr>'
	puts header if header; header = nil
	puts html('th', "sus%", class: 'summary')
	puts html('td', percent(suspicious.inject(:+), total.inject(:+)), class: 'summary')
	suspicious.zip(total).each{|s, t| puts html('td', percent(s, t)) }
	puts '</tr>'
end

puts out.join("\n")

puts '</table>'

puts html('p', "Generated at #{database[:meta].get(:last_updated)} in #{(database[:meta].get(:last_updated_duration)).ceil} seconds.")
puts html('p'){ html('a', 'Source code', href: "https://github.com/MatmaRex/dtcheck") }
