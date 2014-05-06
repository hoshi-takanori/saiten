create table "fresh" (
	"no" integer not null unique,
	"name" text primary key,
	"k_name" text not null,
	"class" integer not null default 0
);

create table "staff" (
	"no" integer not null unique,
	"name" text primary key,
	"k_name" text not null,
	"class" integer not null default 0
);

create table "exercise" (
	"id" text primary key,
	"part" integer not null,
	"chapter" integer not null,
	"number" integer not null,
	"level" integer not null,
	unique (part, chapter, number)
);

create table "hide_exercise" (
	"staff_name" text references staff (name),
	"exercise_id" text references exercise (id),
	primary key (staff_name, exercise_id)
);

create table "staff_exercise" (
	"staff_name" text references staff (name),
	"exercise_id" text references exercise (id),
	primary key (staff_name, exercise_id)
);

create table "answer" (
	"fresh_name" text references fresh (name),
	"exercise_id" text references exercise (id),
	"serial" integer,
	"answer_date" timestamp not null default current_timestamp,
	"status" integer not null default 1 check (status between 1 and 4),
	"staff_name" text references staff (name),
	"reserve_date" timestamp,
	"mark_date" timestamp,
	primary key (fresh_name, exercise_id, serial),
	check ((status = 1 and staff_name is null)
		or (status > 1 and staff_name is not null)),
	check ((status = 1 and reserve_date is null)
		or (status > 1 and reserve_date is not null)),
	check ((status <= 2 and mark_date is null)
		or (status > 2 and mark_date is not null))
);

create function get_status(text, text, integer) returns integer as $$
	select status as result from answer
		where fresh_name = $1 and exercise_id = $2 and serial = $3;
$$ language sql;

alter table "answer" add check (serial = 1
	or (serial > 1 and get_status(fresh_name, exercise_id, serial - 1) = 3));

create table "cancel" (
	"fresh_name" text not null references fresh (name),
	"exercise_id" text not null references exercise (id),
	"serial" integer not null,
	"date" timestamp not null default current_timestamp
);

create table "teisei" (
	"fresh_name" text not null references fresh (name),
	"exercise_id" text not null references exercise (id),
	"serial" integer not null,
	"old_status" integer not null check (old_status between 1 and 4),
	"new_status" integer not null check (new_status between 1 and 4),
	"staff_name" text not null references staff (name),
	"date" timestamp not null default current_timestamp
);

create view "answer_unique" as
	select distinct on (fresh_name, exercise_id) * from answer
		order by fresh_name, exercise_id, serial desc;

grant select on fresh, staff, exercise, hide_exercise,
	staff_exercise, answer, cancel, teisei, answer_unique to public;

grant insert, update, delete on
	hide_exercise, staff_exercise, answer, cancel, teisei to nobody;
