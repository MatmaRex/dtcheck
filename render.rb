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

day_to_check = ARGV[0] || Date.today.iso8601
database = JSON.parse File.read('database.json'), symbolize_names: true

puts '<meta charset="utf-8">'
puts '<link rel="stylesheet" type="text/css" href="styles.css">'
puts '<link rel="stylesheet" type="text/css" href="styles-mw.css">'

title = "Reply tool check for #{day_to_check}"
puts html('title', title)
puts html('h1', title)

yesterday = Date.strptime(day_to_check).prev_day.iso8601
tomorrow = Date.strptime(day_to_check).next_day.iso8601
puts html('a', 'Previous', href: "dtcheck-#{yesterday}.html")
puts '•'
puts html('a', 'Next', href: "dtcheck-#{tomorrow}.html")

suspicious = database[:sites].map{|site, data|
	data[:revisions].values.select{|r| r[:timestamp].start_with? day_to_check }.count{|r| r[:suspicious] }
}.inject(:+)
total = database[:sites].map{|site, data|
	data[:revisions].values.select{|r| r[:timestamp].start_with? day_to_check }.length
}.inject(:+)
percent = total.nonzero? ? (suspicious.to_f/total*100).round(1) : 0
puts html 'p', "#{suspicious} suspicious edits in #{total} replies (#{percent}%)."

if suspicious.nonzero?
	puts html('button', "Toggle all diffs", class: 'diffbuttonall')
end

puts html('ul'){
	database[:sites].map{|site, data|
		html('li') {
			site_suspicious =
				data[:revisions].values.select{|r| r[:timestamp].start_with? day_to_check }.count{|r| r[:suspicious] }
			site_total =
				data[:revisions].values.select{|r| r[:timestamp].start_with? day_to_check }.length

			html(site_suspicious != 0 ? 'a' : nil, site, href: '#' + site.to_s) +
			html(nil, " (#{site_suspicious}/#{site_total})")
		}
	}.join ''
}

out = []
database[:sites].each do |site, site_data|
	revisions = site_data[:revisions].select{|rev, data| data[:timestamp].start_with? day_to_check }
	site_suspicious =
		revisions.select{|rev, data| data[:timestamp].start_with? day_to_check }.count{|rev, data| data[:suspicious] }
	site_total =
		revisions.select{|rev, data| data[:timestamp].start_with? day_to_check }.length

	if site_suspicious == 0
		next
	end

	out << html('h2', site, id: site)

	rows = []
	rows << html('tr'){
		html('th', "Diff") +
		html('th', "Date") +
		html('th', "Revision") +
		html('th', "Notes")
	}

	revisions.each do |rev, data|
		if data[:suspicious]
			diff = data[:diff]
			notes = []

			notes << html('li', "Tags: #{(data[:tags] - ['discussiontools', 'discussiontools-reply']).join ', '}")
			notes << html('li', "Changed lines: +#{diff.scan(/diff-addedline/).length} −#{diff.scan(/diff-deletedline/).length}")

			# wow, this is awful, but i don't want any big dependencies to parse it better or generate my own diffs
			has_deleted_lines_nonempty = diff =~ /<td class="diff-deletedline">(<div>)?[^<]+(<\/div>)?<\/td>\s*<td colspan="2" class="diff-empty">/
			has_deleted_chars_nonwhitespace = diff =~ /<del class="diffchange diffchange-inline">[^<]*[^\s<][^<]*<\/del>/
			if !has_deleted_lines_nonempty && !has_deleted_chars_nonwhitespace
				notes << html('li', "White-space deletions only")
			else
				notes << html('li'){ html('strong', "Non-white-space deletions") }
			end

			has_added_chars = diff =~ /<ins class="diffchange diffchange-inline">[^<]+<\/ins>/
			if has_added_chars
				notes << html('li', "Additions on existing lines")
			end

			if !data[:task_ids].empty?
				notes << html('li'){
					html('abbr', "Related tasks", title: 'Tasks where this revision ID is mentioned') +
					": " +
					data[:task_ids].map{|t|
						html 'a', "T#{t}", href: "https://phabricator.wikimedia.org/T#{t}"
					}.join(', ') }
			end

			rows << html('tr'){
				html('td'){ html('button', "Toggle diff", class: 'diffbutton') } +
				html('td', data[:timestamp]) +
				html('td'){ html('a', rev, href: "https://#{site}/?diff=#{rev}") } +
				html('td'){ html('ul'){ notes.join '' } }
			} + html('tr', style: 'display: none;'){
				html('td', colspan: 4){ make_diff_table diff }
			}
		end
	end

	out << html('p', "#{site_suspicious}/#{site_total} look suspicious")
	out << html('table', class: 'wikitable difftable'){ rows.join '' }
end


puts out

puts html('hr')

puts html('p', "Generated at #{database[:last_updated]} in #{(database[:last_updated_duration]).ceil} seconds.")
puts html('p'){ html('a', 'Source code', href: "https://github.com/MatmaRex/dtcheck") }

puts html('script', src: 'script.js')
