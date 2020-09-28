require 'net/http'
require 'uri'
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

def make_diff_table diff
	diff_header = '<col class="diff-marker" /><col class="diff-content" /><col class="diff-marker" /><col class="diff-content" />'
	html('table', class: 'diff', style: 'font-family: monospace'){
		diff_header + diff
	}
end

def deep_merge_hash a, b
	a.merge(b){|k, old, new|
		case old
		when Hash
			deep_merge_hash old, new
		when Array
			old + new
		else
			new
		end
	}
end

def api_query site, query
	# $stderr.puts query
	JSON.parse Net::HTTP.get URI("https://#{site}/w/api.php?#{query}")
end

def api_query_continue site, query
	out = {}
	query_cont = {}
	while query_cont
		res = api_query site, ([query] + query_cont.map{|k,v| "#{k}=#{CGI.escape v}" }).join('&')
		query_cont = res['continue']
		out = deep_merge_hash out, res
	end
	out
end

sites = %w[
en.wikipedia.org
www.mediawiki.org

ar.wikipedia.org
ca.wikipedia.org
ckb.wikipedia.org
cs.wikipedia.org
fr.wikipedia.org
hu.wikipedia.org
ja.wikipedia.org
ka.wikipedia.org
ko.wikipedia.org
nl.wikipedia.org
sr.wikipedia.org
sv.wikipedia.org
vi.wikipedia.org
zh.wikipedia.org
]

day_to_check = ARGV[0] || Date.now.iso8601

start_time = Time.now

puts '<meta charset="utf-8">'
puts '<link rel="stylesheet" type="text/css" href="styles.css">'
puts '<link rel="stylesheet" type="text/css" href="styles-mw.css">'

title = "Reply tool check for #{day_to_check}"
puts html('title', title)
puts html('h1', title)

yesterday = Date.strptime(day_to_check).prev_day.iso8601
tomorrow = Date.strptime(day_to_check).next_day.iso8601
puts html('a', 'yesterday', href: "dtcheck-#{yesterday}.html")
puts '•'
puts html('a', 'tomorrow', href: "dtcheck-#{tomorrow}.html")

toc = Hash[ sites.map{|site|
	[ site, {
		total: 0,
		suspicious: 0
	} ]
} ]

out = []
sites.each do |site|
	out << html('h2', site, id: site)

	rows = []
	rows << html('tr'){
		html('th', "Diff") +
		html('th', "Date") +
		html('th', "Revision") +
		html('th', "Notes")
	}

	recentchanges = api_query_continue site, "action=query&format=json&list=recentchanges" +
		"&rctag=discussiontools-reply&rcprop=ids|timestamp|tags&rclimit=100" +
		"&rcend=#{day_to_check}T00:00:00Z&rcstart=#{day_to_check}T23:59:59Z"
	recentchanges['query']['recentchanges'].each do |rc|
		rev = rc['revid']
		compare = api_query site, "action=compare&format=json&fromrev=#{rev}&torelative=prev&uselang=en"
		diff = compare['compare']['*'] rescue next
		if diff =~ /diff-deletedline/
			toc[site][:suspicious] += 1
			notes = [
				"Tags: #{(rc['tags'] - ['discussiontools', 'discussiontools-reply']).join ', '}",
				"Changed lines: +#{diff.scan(/diff-addedline/).length} −#{diff.scan(/diff-deletedline/).length}"
			]
			rows << html('tr'){
				html('td'){ html('button', "Toggle diff", class: 'diffbutton') } +
				html('td', rc['timestamp']) +
				html('td'){ html('a', rev, href: "https://#{site}/?diff=#{rev}") } +
				html('td'){ html('ul'){
					notes.map{|line| html 'li', line }.join ''
				} }
			} + html('tr', style: 'display: none;'){
				html('td', colspan: 4){ make_diff_table diff }
			}
		end
		toc[site][:total] += 1
	end

	out << html('p', "#{toc[site][:suspicious]}/#{toc[site][:total]} look suspicious")
	if toc[site][:suspicious].nonzero?
		out << html('button', "Toggle all diffs", class: 'diffbuttonall')
		out << html('table', class: 'wikitable'){ rows.join '' }
	end
end

suspicious = toc.map{|site, data| data[:suspicious] }.inject(:+)
total = toc.map{|site, data| data[:total] }.inject(:+)
percent = total.nonzero? ? (suspicious.to_f/total*100).round(1) : 0
puts html 'p', "#{suspicious} suspicious edits in #{total} replies (#{percent}%)."

puts html('ul'){
	toc.map{|site, data|
		html('li') {
			html('a', site, href: '#' + site) +
			html(nil, " (#{data[:suspicious]}/#{data[:total]})")
		}
	}.join ''
}

puts out

puts html('hr')

end_time = Time.now
puts html('p', "Generated at #{end_time} in #{(end_time - start_time).ceil} seconds.")
puts html('p'){ html('a', 'Source code', href: "https://github.com/MatmaRex/dtcheck") }

puts html('script', src: 'script.js')
