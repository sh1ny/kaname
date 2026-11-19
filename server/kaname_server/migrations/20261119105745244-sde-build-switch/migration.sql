BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "sde_build" ADD COLUMN "previousMarker" boolean;
ALTER TABLE "sde_build" ADD COLUMN "held" boolean NOT NULL DEFAULT false;
CREATE UNIQUE INDEX "sde_build_previous_marker_idx" ON "sde_build" USING btree ("previousMarker");
--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_build_diff" (
    "id" bigserial PRIMARY KEY,
    "fromBuild" bigint NOT NULL,
    "toBuild" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "outcome" text NOT NULL,
    "failureReason" text,
    "report" jsonb
);

-- Indexes
CREATE INDEX "sde_build_diff_builds_idx" ON "sde_build_diff" USING btree ("fromBuild", "toBuild");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_check" (
    "id" bigserial PRIMARY KEY,
    "checkedAt" timestamp without time zone NOT NULL,
    "latestBuild" bigint,
    "outcome" text NOT NULL,
    "failureReason" text
);

-- Indexes
CREATE INDEX "sde_check_checked_at_idx" ON "sde_check" USING btree ("checkedAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_switch" (
    "id" bigserial PRIMARY KEY,
    "kind" text NOT NULL,
    "fromBuild" bigint,
    "toBuild" bigint NOT NULL,
    "at" timestamp without time zone NOT NULL,
    "outcome" text NOT NULL,
    "failureReason" text
);

-- Indexes
CREATE INDEX "sde_switch_at_idx" ON "sde_switch" USING btree ("at");


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261119105745244-sde-build-switch', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261119105745244-sde-build-switch', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
