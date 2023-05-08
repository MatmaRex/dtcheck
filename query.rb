require_relative 'vendor/bundle/bundler/setup'
require 'net/http'
require 'uri'
require 'json'
require 'pp'
require 'cgi'
require 'date'
require 'sequel'

CONDUIT_API_TOKEN = File.read('.conduit_api_token').strip rescue nil

def conduit_query method, params
	return nil if !CONDUIT_API_TOKEN

	api = URI("https://phabricator.wikimedia.org/api/#{method}")
	resp = Net::HTTP.post_form api, params.merge({ 'api.token' => CONDUIT_API_TOKEN })
	return JSON.parse resp.read_body
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

# all Wikimedia sites
res = api_query_continue('meta.wikimedia.org', 'action=sitematrix&format=json&smlimit=5000&formatversion=2')
res_lang = res['sitematrix']
	.select{|k, v| k =~ /^\d+$/ }
	.values
	.map{|a| a['site'] }
	.flatten
res_site = res['sitematrix']['specials']
urls = ( res_lang + res_site )
	.reject{|a| a['private'] || a['closed'] }
	.map{|a| a['url'] }
sites = urls.map{|a| a.sub 'https://', '' }

start_time = Time.now

database = Sequel.sqlite 'database.sqlite'
if database.tables.empty?
	database.run File.read 'schema.sql'
end

from_date = ARGV[0] || Date.today.iso8601
to_date = ARGV[1] || Date.today.iso8601

sites.each do |site|
	puts site
	recentchanges = api_query_continue site, "action=query&format=json&list=recentchanges" +
		"&rctag=discussiontools-reply&rcprop=ids|timestamp|title|tags|sizes&rclimit=100" +
		"&rcend=#{from_date}T00:00:00Z&rcstart=#{to_date}T23:59:59Z"
	recentchanges['query']['recentchanges'].each do |rc|
		rev = rc['revid']
		oldrev = rc['old_revid']
		suspicious = false

		row = database[:siterevs].where({ site: site, revision: rev }).first || { site: site, revision: rev }
		row[:timestamp] = rc['timestamp']
		row[:title] = rc['title']
		row[:diffsize] = rc['newlen'] - rc['oldlen'] rescue nil

		if !row[:diff] || !row[:oldrev]
			compare = api_query site, "action=compare&format=json&fromrev=#{oldrev}&torev=#{rev}&uselang=en" rescue next
			diff = compare['compare']['*'] rescue next
		else
			diff = row[:diff]
		end

		if diff =~ /diff-deletedline/
			suspicious = true
		end

		if suspicious
			row[:suspicious] = suspicious
			row[:diff] = diff
			row[:oldrev] = oldrev

			resp = conduit_query 'maniphest.search', {'constraints[query]' => rev}
			if resp
				task_ids = resp['result']['data'].map{|a| a['id'] }
				row[:task_ids] = task_ids.to_json
			end
		else
			row.delete :suspicious
		end

		siterevid = database[:siterevs].insert_conflict(:replace).insert row
		rc['tags'].each{|tag|
			tagid = database[:tags].where(tag: tag).get(:tagid)
			tagid = database[:tags].insert( { tag: tag } ) if !tagid
			database[:revtags].insert_conflict(:ignore).insert( { siterevid: siterevid, tagid: tagid } )
		}
	end
end

end_time = Time.now

database[:meta].update( {
	last_updated: end_time,
	last_updated_duration: end_time - start_time,
} )
