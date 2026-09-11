# DoltgreSQL 1.3.1: `information_schema.triggers` is empty while the trigger exists and fires

On DoltgreSQL 1.3.1, `information_schema.triggers` answers `(0 rows)` for a trigger that exists: the trigger
fires on `INSERT`, and `pg_trigger` lists it. PostgreSQL 18.6 lists the same trigger in both catalogs: the
view answers one row with trigger `t_report`, event `INSERT` and table `t`.

## Reproduce it

You need Docker and a POSIX shell: Linux, macOS, or Windows with WSL. The first run downloads the images.

```sh
git clone https://github.com/Reliable-Collaboration/repro-doltgresql-bug-information-schema-triggers.git
cd repro-doltgresql-bug-information-schema-triggers
./repro.sh
```

`repro.sh` starts a throwaway PostgreSQL 18.6 container and a throwaway DoltgreSQL 1.3.1 container, runs
[`repro.sql`](repro.sql) on each with the `psql` client inside that container, and prints the two outputs
side by side, marking the lines that differ. It exits 1 while DoltgreSQL's output differs from
PostgreSQL's and 0 once they are identical, and it removes both containers when it finishes.

To try another DoltgreSQL release, name its image:

```sh
DOLTGRESQL_IMAGE=dolthub/doltgresql:latest ./repro.sh
```

### Without the script

The same steps by hand, from the repository directory:

```sh
docker run -d --name repro-doltgresql-bug-information-schema-triggers-postgres -e POSTGRES_PASSWORD=password postgres:18.6-bookworm
docker run -d --name repro-doltgresql-bug-information-schema-triggers-doltgresql -e DOLTGRES_PASSWORD=password dolthub/doltgresql:1.3.1
docker cp repro.sql repro-doltgresql-bug-information-schema-triggers-postgres:/tmp/repro.sql
docker cp repro.sql repro-doltgresql-bug-information-schema-triggers-doltgresql:/tmp/repro.sql
docker exec -t -e PGPASSWORD=password repro-doltgresql-bug-information-schema-triggers-postgres psql -X -P pager=off -h 127.0.0.1 -U postgres -d postgres --echo-all -f /tmp/repro.sql
docker exec -t -e PGPASSWORD=password repro-doltgresql-bug-information-schema-triggers-doltgresql psql -X -P pager=off -h 127.0.0.1 -U postgres -d postgres --echo-all -f /tmp/repro.sql
docker rm -f repro-doltgresql-bug-information-schema-triggers-postgres repro-doltgresql-bug-information-schema-triggers-doltgresql
```

If a `docker exec` answers that the connection was refused, that server is still starting: wait a few
seconds and run it again.

## The test

[`repro.sql`](repro.sql):

```sql
-- One table, one trigger function, and one trigger.
CREATE TABLE t (a int);

CREATE FUNCTION report_row() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE 'trigger fired for a = %', NEW.a;
    RETURN NEW;
END;
$$;

CREATE TRIGGER t_report BEFORE INSERT ON t
    FOR EACH ROW EXECUTE FUNCTION report_row();

-- The trigger fires, and prints its notice.
INSERT INTO t VALUES (1);

-- The trigger in information_schema.triggers.
SELECT trigger_name, event_manipulation,
       event_object_table
FROM information_schema.triggers;

-- The trigger in pg_trigger.
SELECT tgname FROM pg_trigger
WHERE tgrelid = 't'::regclass;
```

## Expected behavior

The trigger fires and prints its notice, and both catalogs list it: `information_schema.triggers` answers
one row with the trigger's name, its event and its table, and `pg_trigger` answers its name. This is what
PostgreSQL 18.6 does:

```
-- The trigger fires, and prints its notice.
INSERT INTO t VALUES (1);
psql:/tmp/repro.sql:16: NOTICE:  trigger fired for a = 1
INSERT 0 1
-- The trigger in information_schema.triggers.
SELECT trigger_name, event_manipulation,
       event_object_table
FROM information_schema.triggers;
 trigger_name | event_manipulation | event_object_table 
--------------+--------------------+--------------------
 t_report     | INSERT             | t
(1 row)

-- The trigger in pg_trigger.
SELECT tgname FROM pg_trigger
WHERE tgrelid = 't'::regclass;
  tgname  
----------
 t_report
(1 row)
```

## Actual behavior

The trigger fires and prints the same notice, and `pg_trigger` lists it, but `information_schema.triggers`
answers `(0 rows)`. The view's column names also come back in upper case. This is what DoltgreSQL 1.3.1
does:

```
-- The trigger fires, and prints its notice.
INSERT INTO t VALUES (1);
psql:/tmp/repro.sql:16: NOTICE:  trigger fired for a = 1
INSERT 0 1
-- The trigger in information_schema.triggers.
SELECT trigger_name, event_manipulation,
       event_object_table
FROM information_schema.triggers;
 TRIGGER_NAME | EVENT_MANIPULATION | EVENT_OBJECT_TABLE 
--------------+--------------------+--------------------
(0 rows)

-- The trigger in pg_trigger.
SELECT tgname FROM pg_trigger
WHERE tgrelid = 't'::regclass;
  tgname  
----------
 t_report
(1 row)
```

## Side by side

The output of `./repro.sh`:

```
Starting postgres:18.6-bookworm@sha256:1c59e2c3c818eaa0f0628f695b36e7c9e362d6b219b36a54a32df645cbd7e1af
Starting dolthub/doltgresql:1.3.1@sha256:6c85cb1f35beabf47f094336a420255130b841b1645f36d79ef046276af36851

Left: PostgreSQL. Right: DoltgreSQL. Lines that differ are marked with |.

-- One table, one trigger function, and one trigger.          -- One table, one trigger function, and one trigger.
CREATE TABLE t (a int);                                       CREATE TABLE t (a int);
CREATE TABLE                                                  CREATE TABLE
CREATE FUNCTION report_row() RETURNS trigger                  CREATE FUNCTION report_row() RETURNS trigger
LANGUAGE plpgsql AS $$                                        LANGUAGE plpgsql AS $$
BEGIN                                                         BEGIN
    RAISE NOTICE 'trigger fired for a = %', NEW.a;                RAISE NOTICE 'trigger fired for a = %', NEW.a;
    RETURN NEW;                                                   RETURN NEW;
END;                                                          END;
$$;                                                           $$;
CREATE FUNCTION                                               CREATE FUNCTION
CREATE TRIGGER t_report BEFORE INSERT ON t                    CREATE TRIGGER t_report BEFORE INSERT ON t
    FOR EACH ROW EXECUTE FUNCTION report_row();                   FOR EACH ROW EXECUTE FUNCTION report_row();
CREATE TRIGGER                                                CREATE TRIGGER
-- The trigger fires, and prints its notice.                  -- The trigger fires, and prints its notice.
INSERT INTO t VALUES (1);                                     INSERT INTO t VALUES (1);
psql:/tmp/repro.sql:16: NOTICE:  trigger fired for a = 1      psql:/tmp/repro.sql:16: NOTICE:  trigger fired for a = 1
INSERT 0 1                                                    INSERT 0 1
-- The trigger in information_schema.triggers.                -- The trigger in information_schema.triggers.
SELECT trigger_name, event_manipulation,                      SELECT trigger_name, event_manipulation,
       event_object_table                                            event_object_table
FROM information_schema.triggers;                             FROM information_schema.triggers;
 trigger_name | event_manipulation | event_object_table     |  TRIGGER_NAME | EVENT_MANIPULATION | EVENT_OBJECT_TABLE 
--------------+--------------------+--------------------      --------------+--------------------+--------------------
 t_report     | INSERT             | t                      | (0 rows)
(1 row)                                                     <

-- The trigger in pg_trigger.                                 -- The trigger in pg_trigger.
SELECT tgname FROM pg_trigger                                 SELECT tgname FROM pg_trigger
WHERE tgrelid = 't'::regclass;                                WHERE tgrelid = 't'::regclass;
  tgname                                                        tgname  
----------                                                    ----------
 t_report                                                      t_report
(1 row)                                                       (1 row)


Result: DoltgreSQL's output differs from PostgreSQL's on 2 line(s), marked with |.
```

## Other observations

Each was checked on DoltgreSQL 1.3.1 and PostgreSQL 18.6 with the same kind of test:

- Every trigger tried is missing from the view: `BEFORE INSERT`, `AFTER INSERT`, `AFTER UPDATE`,
  `BEFORE DELETE` and `AFTER INSERT OR UPDATE` row triggers. With eight triggers, `pg_trigger` lists all
  eight on both servers, and the view counts 0 on DoltgreSQL and 8 on PostgreSQL.
- The view is also empty for a trigger on a table in another schema, for a trigger in a second database,
  from a new connection, and, on DoltgreSQL, after `SELECT dolt_commit('-Am', 'triggers')`.
- On DoltgreSQL, `SELECT * FROM information_schema.triggers` has 22 columns named in upper case, among them
  `SQL_MODE`, `DEFINER`, `CHARACTER_SET_CLIENT`, `COLLATION_CONNECTION` and `DATABASE_COLLATION`.
  PostgreSQL's view has 17 columns, none of those.
- `information_schema.triggered_update_columns` does not exist on DoltgreSQL
  (`ERROR:  table not found: triggered_update_columns`). PostgreSQL answers `(0 rows)`.
- `pg_get_triggerdef()` returns the `CREATE TRIGGER` statement as it was typed, with its line break and an
  unqualified table name, where PostgreSQL returns one line with `ON public.t`.
- The test's trigger function prints a notice because on DoltgreSQL 1.3.1 a trigger function that assigns
  to a field of `NEW`, such as `NEW.b := NEW.a + 1;`, makes the `INSERT` fail with
  `ERROR:  receiveMessage recovered panic: runtime error: index out of range [1] with length 1`, a separate
  bug. PostgreSQL runs it.

## Environment

- DoltgreSQL 1.3.1, the newest release when this was written: image `dolthub/doltgresql:1.3.1`, digest
  `sha256:6c85cb1f35beabf47f094336a420255130b841b1645f36d79ef046276af36851`, built for linux/amd64 and
  linux/arm64. Its bundled `psql` is 17.11.
- PostgreSQL 18.6: image `postgres:18.6-bookworm`, digest
  `sha256:1c59e2c3c818eaa0f0628f695b36e7c9e362d6b219b36a54a32df645cbd7e1af`. Its `psql` is 18.6.
- Reproduced on 2026-09-11 (UTC) with Docker 29.7.2 on Ubuntu 26.04.1 LTS under WSL2 (Linux 6.18.33.2,
  x86_64).
