create table siterevs(
	siterevid integer primary key,
	site text,
	revision integer,
	timestamp text,
	title text,
	diffsize integer,
	suspicious integer,
	diff text,
	oldrev integer,
	task_ids text
);
create unique index siterev_site_revision on siterevs(site, revision);
create index siterev_timestamp on siterevs(timestamp);
create index siterev_datetimestamp on siterevs(date(timestamp));
create index siterev_site_datetimestamp on siterevs(site, date(timestamp));

create table tags(
	tagid integer primary key,
	tag text
);
create unique index tags_tag on tags(tag);

create table revtags(
	siterevid integer,
	tagid integer,
	primary key (siterevid, tagid)
) without rowid;

create table meta(
	id integer primary key check (id = 1), -- `check` ensures that there is only 1 row
	last_updated default '?',
	last_updated_duration default -1
);
insert into meta default values;
