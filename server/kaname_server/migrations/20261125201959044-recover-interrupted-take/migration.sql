BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "esi_holder_assignment" ADD COLUMN "takeClosures" bigint;

--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261125201959044-recover-interrupted-take', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261125201959044-recover-interrupted-take', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
