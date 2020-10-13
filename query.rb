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
en.wikipedia.org
en.wikiversity.org
www.mediawiki.org
meta.wikimedia.org

am.wikipedia.org
ar.wikipedia.org
as.wikipedia.org
bh.wikipedia.org
ca.wikipedia.org
ckb.wikipedia.org
cs.wikipedia.org
es.wikipedia.org
eu.wikipedia.org
fa.wikipedia.org
fi.wikipedia.org
fr.wikipedia.org
he.wikipedia.org
hi.wikipedia.org
hu.wikipedia.org
hy.wikipedia.org
is.wikipedia.org
it.wikipedia.org
ja.wikipedia.org
ka.wikipedia.org
ko.wikipedia.org
lt.wikipedia.org
mai.wikipedia.org
mnw.wikipedia.org
mr.wikipedia.org
my.wikipedia.org
ne.wikipedia.org
nl.wikipedia.org
no.wikipedia.org
nqo.wikipedia.org
pa.wikipedia.org
pl.wikipedia.org
pt.wikipedia.org
sat.wikipedia.org
si.wikipedia.org
sr.wikipedia.org
sv.wikipedia.org
ta.wikipedia.org
th.wikipedia.org
tr.wikipedia.org
uk.wikipedia.org
vi.wikipedia.org
zh.wikipedia.org
].map{|s| s.to_sym}

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
		"&rctag=discussiontools-reply&rcprop=ids|timestamp|tags&rclimit=100" +
		"&rcend=#{from_date}T00:00:00Z&rcstart=#{to_date}T23:59:59Z"
	recentchanges['query']['recentchanges'].each do |rc|
		rev = rc['revid']
		if !database[:sites][site][:revisions][rev]
			database[:sites][site][:revisions][rev] ||= {}
			database[:sites][site][:revisions][rev][:tags] = rc['tags']
			database[:sites][site][:revisions][rev][:timestamp] = rc['timestamp']

			compare = api_query site, "action=compare&format=json&fromrev=#{rev}&torelative=prev&uselang=en" rescue next
			diff = compare['compare']['*'] rescue next
			if diff =~ /diff-deletedline/
				database[:sites][site][:revisions][rev][:suspicious] = true
				database[:sites][site][:revisions][rev][:diff] = diff
			end
		end
		if database[:sites][site][:revisions][rev][:suspicious]
			resp = conduit_query 'maniphest.search', {'constraints[query]' => rev}
			if resp
				task_ids = resp['result']['data'].map{|a| a['id'] }
				database[:sites][site][:revisions][rev][:task_ids] = task_ids
			end
		end
	end
end

end_time = Time.now

database[:last_updated] = end_time
database[:last_updated_duration] = end_time - start_time

File.write 'database.json', JSON.pretty_generate(database)
