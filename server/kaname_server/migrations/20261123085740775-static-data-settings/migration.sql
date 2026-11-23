BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_admin_operation" (
    "id" bigserial PRIMARY KEY,
    "operationId" uuid NOT NULL,
    "kind" text NOT NULL,
    "expectedRevision" bigint,
    "state" text NOT NULL,
    "outcome" text,
    "failureReason" text,
    "activeBuild" bigint,
    "changedBuilds" boolean NOT NULL DEFAULT false,
    "createdAt" timestamp without time zone NOT NULL,
    "endedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "sde_admin_operation__operationId__unique_idx" ON "sde_admin_operation" USING btree ("operationId");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "sde_build_diff" ADD COLUMN "reportBytes" bigint;
--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_build_revision" (
    "id" bigserial PRIMARY KEY,
    "revision" bigint NOT NULL
);

--
-- ACTION ALTER TABLE
--
ALTER TABLE "sde_check" ADD COLUMN "trigger" text NOT NULL DEFAULT 'daily'::text;
ALTER TABLE "sde_check" ADD COLUMN "lookupStarted" boolean;
ALTER TABLE "sde_check" ADD COLUMN "lookupStartedAt" timestamp without time zone;
--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_setting_write" (
    "id" bigserial PRIMARY KEY,
    "writeId" uuid NOT NULL,
    "autoUpdate" boolean NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_setting_write__writeId__unique_idx" ON "sde_setting_write" USING btree ("writeId");

-- Keep the newest report for each direction; a same-time row with a larger
-- id is newer. Backfill the uncompressed JSON byte length before recording
-- the upgrade so neither transformation can be applied only in part.
WITH ranked AS (
    SELECT id, row_number() OVER (
        PARTITION BY "fromBuild", "toBuild" ORDER BY "createdAt" DESC, id DESC
    ) AS position
    FROM "sde_build_diff"
)
DELETE FROM "sde_build_diff" AS diff
USING ranked
WHERE diff.id = ranked.id AND ranked.position > 1;

UPDATE "sde_build_diff"
SET "reportBytes" = octet_length(report::text)
WHERE outcome = 'succeeded' AND report IS NOT NULL;


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261123085740775-static-data-settings', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261123085740775-static-data-settings', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
