# https://phabricator.wikimedia.org/T215599#4941087
# https://wikitech.wikimedia.org/wiki/News/Toolforge_Stretch_deprecation#Move_a_grid_engine_webservice
# Can't use Kubernetes, because there's no configuration that allows both
# serving static HTML files using lighttpd and running CGI scripts using Ruby.
webservice --backend=gridengine --release buster lighttpd start
