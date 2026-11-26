BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "esi_holder_assignment" ADD COLUMN "lastTakeClosureAt" timestamp without time zone;

--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261126115602678-bound-take-closures', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261126115602678-bound-take-closures', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
