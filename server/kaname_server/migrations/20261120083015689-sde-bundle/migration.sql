BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_bundle" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "outcome" text NOT NULL,
    "reason" text,
    "formatMajor" bigint NOT NULL,
    "formatMinor" bigint NOT NULL,
    "sha256" text,
    "size" bigint,
    "builtAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_bundle_build_idx" ON "sde_bundle" USING btree ("build");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_bundle_bytes" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sha256" text NOT NULL,
    "bytes" bytea NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_bundle_bytes_build_sha256_idx" ON "sde_bundle_bytes" USING btree ("build", "sha256");


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261120083015689-sde-bundle', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261120083015689-sde-bundle', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
