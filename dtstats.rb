require 'cgi'
cgi = CGI.new

month = cgi.params['month'].last
if month && month !~ /^\d{4}-\d{2}$/
	cgi.out( 'status' => 'BAD_REQUEST' ){ 'Bad request' }
	exit
end

fields = cgi.params['field'] || []
unless fields.all?{|f| %w[sus good total suspc].include? f }
	cgi.out( 'status' => 'BAD_REQUEST' ){ 'Bad request' }
	exit
end

sort_date = cgi.params['sort_date'].last
if sort_date && sort_date != '' && sort_date !~ /^\d{4}-\d{2}-\d{2}$/
	cgi.out( 'status' => 'BAD_REQUEST' ){ 'Bad request' }
	exit
end

output = `ruby render_stats.rb "#{month}" "#{fields.join(',')}" "#{sort_date}"`

cgi.out{ output }
