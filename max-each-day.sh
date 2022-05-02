sqlite3 -column database.sqlite "select date(timestamp), max( time(timestamp) ) from revisions group by date(timestamp)"
