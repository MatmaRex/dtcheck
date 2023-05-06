sqlite3 -column database.sqlite "select date(timestamp), max( time(timestamp) ) from siterevs group by date(timestamp)"
