sqlite3 -column database.sqlite "select date(timestamp), max( time(timestamp) ), count(distinct site) from siterevs group by date(timestamp)"
