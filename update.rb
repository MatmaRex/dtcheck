require 'date'

count = ARGV[0] || 0
count = count.to_i
# recent changes entries only last 30 days
count = count.clamp(1, 30)

start_time = Time.now

date = Date.today
puts date
system "ruby dtcheck.rb #{date.iso8601} > dtcheck-#{date.iso8601}.html"
count.times {
	date = date.prev_day
	puts date
	system "ruby dtcheck.rb #{date.iso8601} > dtcheck-#{date.iso8601}.html"
}

end_time = Time.now
puts "Total time: #{end_time - start_time} seconds."
