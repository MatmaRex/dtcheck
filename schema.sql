create table revisions(
	site, revid, tags, timestamp, title, diffsize, suspicious, diff, oldrev, task_ids
);
create unique index revisions_site_revid on revisions(site, revid);
create index revisions_timestamp on revisions(timestamp);
create index revisions_datetimestamp on revisions(date(timestamp));
create index revisions_site_datetimestamp on revisions(site, date(timestamp));

create table meta(
	id integer primary key check (id = 1), -- `check` ensures that there is only 1 row
	last_updated default null,
	last_updated_duration default null
);
insert into meta default values;
