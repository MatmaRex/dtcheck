require_relative 'vendor/bundle/bundler/setup'
require 'json'
require 'pp'
require 'sequel'

File.rename 'database.sqlite', 'database.sqlite.old'

database = Sequel.sqlite 'database.sqlite'
database.run File.read 'schema.sql'

database.run 'attach database "database.sqlite.old" as old'

database.run "
insert into siterevs
select rowid, site, revid, timestamp, title, diffsize, suspicious, diff, oldrev, task_ids
from revisions
"

# require 'logger'
# database.logger = Logger.new($stdout)

all_tags = {}
database.transaction do
	database[:revisions].select_append(:rowid).each do |data|
		tags = JSON.parse(data[:tags])

		tags.each do |tag|
			if !all_tags[tag]
				tagid = database[:tags].insert( { tag: tag } )
				all_tags[tag] = tagid
			end

			database[:revtags].insert( { siterevid: data[:rowid], tagid: all_tags[tag] } )
		end
	end
end
