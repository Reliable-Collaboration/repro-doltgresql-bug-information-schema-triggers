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
