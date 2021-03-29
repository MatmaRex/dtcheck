require 'date'

count = ARGV[0] || 0
count = count.to_i
# recent changes entries only last 30 days
count = [0, count, 30].sort[1]

start_time = Time.now
date = Date.today

puts 'Querying...'
system "ruby query.rb #{(date-count).iso8601}"

puts date
system "ruby render.rb #{date.iso8601} > dtcheck-#{date.iso8601}.html"
count.times {
	date = date.prev_day
	puts date
	system "ruby render.rb #{date.iso8601} > dtcheck-#{date.iso8601}.html"
}

system "ruby render_stats.rb > dtstats.html"

month = Date.today
while month > Date.new(2020, 9)
	month = month.prev_month
	puts month.strftime('%Y-%m')
	system "ruby render_stats.rb #{month.strftime('%Y-%m')} > dtstats-#{month.strftime('%Y-%m')}.html"
end

end_time = Time.now
puts "Total time: #{end_time - start_time} seconds."
