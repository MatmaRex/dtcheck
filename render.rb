require_relative 'vendor/bundle/bundler/setup'
require 'json'
require 'pp'
require 'cgi'
require 'date'
require 'sequel'

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
database = Sequel.sqlite 'database.sqlite'

puts '<meta charset="utf-8">'
puts '<link rel="stylesheet" type="text/css" href="styles.css">'
puts '<link rel="stylesheet" type="text/css" href="styles-mw.css">'

title = "Reply tool check for #{day_to_check}"
puts html('title', title)
puts html('h1', title)

puts File.read 'banner.html'

yesterday = Date.strptime(day_to_check).prev_day.iso8601
tomorrow = Date.strptime(day_to_check).next_day.iso8601
puts html('a', 'Previous', href: "dtcheck-#{yesterday}.html")
puts '•'
puts html('a', 'Next', href: "dtcheck-#{tomorrow}.html")

suspicious = database.fetch("select sum(suspicious) from siterevs where date(timestamp) = ?", day_to_check).get || 0
total = database.fetch("select count(*) from siterevs where date(timestamp) = ?", day_to_check).get
percent = total.nonzero? ? (suspicious.to_f/total*100).round(1) : 0
puts html 'p', "#{suspicious} suspicious edits in #{total} replies (#{percent}%)."

if suspicious.nonzero?
	puts html('p'){ html('button', "Toggle all diffs", class: 'diffbuttonall') }
end


toc = html('ul'){
	database.fetch("select site, sum(suspicious), count(*) from siterevs where date(timestamp) = ? group by site", day_to_check).map{|row|
		html('li') {
			site = row[:site]
			site_suspicious = row[:'sum(suspicious)'] || 0
			site_total = row[:'count(*)']

			html(site_suspicious != 0 ? 'a' : nil, site, href: '#' + site.to_s) +
			html(nil, " (#{site_suspicious}/#{site_total})")
		}
	}.join ''
}
puts html('details'){
	html('summary', "Table of contents / Overview") + toc
}

out = []
database.fetch("select distinct site from siterevs").map(:site).each do |site|
	revisions = database.fetch("select * from siterevs where site = ? and date(timestamp) = ?", site, day_to_check).all

	site_suspicious =
		revisions.select{|data| data[:timestamp].start_with? day_to_check }.count{|data| data[:suspicious] }
	site_total =
		revisions.select{|data| data[:timestamp].start_with? day_to_check }.length

	if site_suspicious == 0
		next
	end

	out << html('h2', site, id: site)

	rows = []
	rows << html('tr'){
		html('th', "Diff") +
		html('th', "Date") +
		html('th', "Title") +
		html('th', "Revision") +
		html('th', "Notes")
	}

	revisions.each do |data|
		tagids = database[:revtags].where(siterevid: data[:siterevid]).map(:tagid)
		tags = database[:tags].where(tagid: tagids).map(:tag)

		rev = data[:revision]

		if data[:suspicious]
			diff = data[:diff]
			notes = []

			notes << html('li'){
				interesting_tags = tags - ['discussiontools', 'discussiontools-reply']
				tags_html = interesting_tags.map{|t|
					sus_tag = ['mw-reverted'].include?(t)
					html(sus_tag ? 'strong' : nil, t)
				}
				"Tags: #{tags_html.join ', '}"
			}

			notes << html('li', "Changed lines: +#{diff.scan(/diff-addedline/).length} −#{diff.scan(/diff-deletedline/).length}")

			# wow, this is awful, but i don't want any big dependencies to parse it better or generate my own diffs
			has_deleted_lines_nonempty = diff =~ /<td class="diff-deletedline(?: diff-side-deleted)?">(<div>)?[^<]+(<\/div>)?<\/td>\s*<td colspan="2" class="diff-empty(?: diff-side-added)?">/
			has_deleted_chars_nonwhitespace = diff =~ /<del class="diffchange diffchange-inline">[^<]*[^\s<][^<]*<\/del>/
			if !has_deleted_lines_nonempty && !has_deleted_chars_nonwhitespace
				notes << html('li', "White-space deletions only")
			elsif diff.scan(/diff-deletedline/).length.nonzero?
				notes << html('li'){ html('strong', "Non-white-space deletions") }
			end

			has_added_chars = diff =~ /<ins class="diffchange diffchange-inline">[^<]+<\/ins>/
			if has_added_chars
				notes << html('li', "Additions on existing lines")
			end

			if data[:task_ids] && data[:task_ids] != '[]'
				notes << html('li'){
					html('abbr', "Related tasks", title: 'Tasks where this revision ID is mentioned') +
					": " +
					JSON.parse(data[:task_ids]).map{|t|
						html 'a', "T#{t}", href: "https://phabricator.wikimedia.org/T#{t}"
					}.join(', ') }
			end

			rows << html('tr'){
				html('td'){ html('button', "Toggle diff", class: 'diffbutton') } +
				html('td', data[:timestamp]) +
				html('td'){
					data[:title] ?
						html('a', data[:title], href: "https://#{site}/?title=#{CGI.escape data[:title]}") :
						'?'
				} +
				html('td'){ html('a', rev, href: "https://#{site}/?diff=#{rev}") } +
				html('td'){ html('ul'){ notes.join '' } }
			} + html('tr', style: 'display: none;'){
				html('td', colspan: 5){ make_diff_table diff }
			}
		end
	end

	out << html('p', "#{site_suspicious}/#{site_total} look suspicious")
	out << html('table', class: 'wikitable difftable'){ rows.join '' }
end


puts out

puts html('hr')

puts html('p', "Generated at #{database[:meta].get(:last_updated)} in #{(database[:meta].get(:last_updated_duration)).ceil} seconds.")
puts html('p'){ html('a', 'Source code', href: "https://github.com/MatmaRex/dtcheck") }

puts html('script', src: 'script.js')
