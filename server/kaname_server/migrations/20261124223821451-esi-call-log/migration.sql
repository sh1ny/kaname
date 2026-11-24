BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "esi_call_log_entry" (
    "id" bigserial PRIMARY KEY,
    "recordedAt" timestamp without time zone NOT NULL,
    "operation" text NOT NULL,
    "outcome" text NOT NULL,
    "status" bigint,
    "cost" bigint,
    "latencyMicros" bigint NOT NULL,
    "bucket" text,
    "memberId" bigint,
    "characterId" bigint
);

-- Indexes
CREATE INDEX "esi_call_log_retention_idx" ON "esi_call_log_entry" USING btree ("recordedAt", "id");
CREATE INDEX "esi_call_log_owner_idx" ON "esi_call_log_entry" USING btree ("memberId", "recordedAt", "id");


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261124223821451-esi-call-log', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261124223821451-esi-call-log', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
