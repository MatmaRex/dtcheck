require 'net/http'
require 'uri'
require 'json'
require 'pp'
require 'cgi'
require 'date'

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

sites = %w[
en.wikiversity.org
www.mediawiki.org
meta.wikimedia.org
].map{|s| s.to_sym}

# add all wikipedias
res = api_query_continue('meta.wikimedia.org', 'action=sitematrix&format=json')
res = res['sitematrix']
	.select{|k, v| k =~ /^\d+$/ }
	.values
	.map{|a| a['site']}
	.flatten
	.map{|a| a['url']}
	.grep(/wikipedia/)
sites += res.map{|a| a.sub 'https://', '' }.map{|s| s.to_sym}

start_time = Time.now

if File.exist? 'database.json'
	database = JSON.parse File.read('database.json'), symbolize_names: true
else
	database = {
		sites: {},
		last_updated: nil,
		last_updated_duration: nil
	}
end

from_date = ARGV[0] || Date.today.iso8601
to_date = ARGV[1] || Date.today.iso8601

sites.each do |site|
	database[:sites][site] ||= {
		revisions: {}
	}

	recentchanges = api_query_continue site, "action=query&format=json&list=recentchanges" +
		"&rctag=discussiontools-reply&rcprop=ids|timestamp|tags|sizes&rclimit=100" +
		"&rcend=#{from_date}T00:00:00Z&rcstart=#{to_date}T23:59:59Z"
	recentchanges['query']['recentchanges'].each do |rc|
		rev = rc['revid']
		suspicious = false

		database[:sites][site][:revisions][rev] ||= {}
		database[:sites][site][:revisions][rev][:tags] = rc['tags']
		database[:sites][site][:revisions][rev][:timestamp] = rc['timestamp']
		database[:sites][site][:revisions][rev][:diffsize] = rc['newlen'] - rc['oldlen'] rescue nil

		if !database[:sites][site][:revisions][rev][:diff]
			compare = api_query site, "action=compare&format=json&fromrev=#{rev}&torelative=prev&uselang=en" rescue next
			diff = compare['compare']['*'] rescue next
		else
			diff = database[:sites][site][:revisions][rev][:diff]
		end

		if diff =~ /diff-deletedline/
			suspicious = true
		end

		if suspicious
			database[:sites][site][:revisions][rev][:suspicious] = suspicious
			database[:sites][site][:revisions][rev][:diff] = diff

			resp = conduit_query 'maniphest.search', {'constraints[query]' => rev}
			if resp
				task_ids = resp['result']['data'].map{|a| a['id'] }
				database[:sites][site][:revisions][rev][:task_ids] = task_ids
			end
		else
			database[:sites][site][:revisions][rev].delete :suspicious
		end
	end
end

end_time = Time.now

database[:last_updated] = end_time
database[:last_updated_duration] = end_time - start_time

File.write 'database.json', JSON.pretty_generate(database)
