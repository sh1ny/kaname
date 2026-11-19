BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_build" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "state" text NOT NULL,
    "importedAt" timestamp without time zone NOT NULL,
    "activeMarker" boolean
);

-- Indexes
CREATE UNIQUE INDEX "sde_build_build_idx" ON "sde_build" USING btree ("build");
CREATE UNIQUE INDEX "sde_build_active_marker_idx" ON "sde_build" USING btree ("activeMarker");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_category" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "name" text,
    "published" boolean,
    "iconId" bigint,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_category_build_sde_id_idx" ON "sde_category" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_constellation" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "regionId" bigint,
    "name" text,
    "factionId" bigint,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_constellation_build_sde_id_idx" ON "sde_constellation" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_dogma_attribute" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "name" text,
    "displayName" text,
    "attributeCategoryId" bigint,
    "unitId" bigint,
    "defaultValue" double precision,
    "published" boolean,
    "highIsGood" boolean,
    "stackable" boolean,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_dogma_attribute_build_sde_id_idx" ON "sde_dogma_attribute" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_dogma_attribute_category" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "name" text,
    "description" text,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_dogma_attribute_category_build_sde_id_idx" ON "sde_dogma_attribute_category" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_dogma_effect" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "name" text,
    "displayName" text,
    "effectCategoryId" bigint,
    "published" boolean,
    "isOffensive" boolean,
    "isAssistance" boolean,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_dogma_effect_build_sde_id_idx" ON "sde_dogma_effect" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_dogma_unit" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "name" text,
    "displayName" text,
    "description" text,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_dogma_unit_build_sde_id_idx" ON "sde_dogma_unit" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_group" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "categoryId" bigint,
    "name" text,
    "published" boolean,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_group_build_sde_id_idx" ON "sde_group" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_import" (
    "id" bigserial PRIMARY KEY,
    "build" bigint,
    "source" text NOT NULL,
    "startedAt" timestamp without time zone NOT NULL,
    "finishedAt" timestamp without time zone,
    "outcome" text NOT NULL,
    "failureReason" text,
    "fileCounts" jsonb,
    "drift" jsonb,
    "badRecords" jsonb,
    "knownIds" jsonb,
    "fieldCheck" jsonb
);

-- Indexes
CREATE INDEX "sde_import_started_at_idx" ON "sde_import" USING btree ("startedAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_market_group" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "name" text,
    "parentGroupId" bigint,
    "hasTypes" boolean,
    "iconId" bigint,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_market_group_build_sde_id_idx" ON "sde_market_group" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_meta_group" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "name" text,
    "iconId" bigint,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_meta_group_build_sde_id_idx" ON "sde_meta_group" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_record" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "file" text NOT NULL,
    "line" bigint NOT NULL,
    "key" text NOT NULL,
    "record" jsonb NOT NULL
);

-- Indexes
CREATE INDEX "sde_record_build_file_idx" ON "sde_record" USING btree ("build", "file");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_region" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "name" text,
    "factionId" bigint,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_region_build_sde_id_idx" ON "sde_region" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_solar_system" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "constellationId" bigint,
    "regionId" bigint,
    "name" text,
    "securityStatus" double precision,
    "securityClass" text,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_solar_system_build_sde_id_idx" ON "sde_solar_system" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_type" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "groupId" bigint,
    "name" text,
    "published" boolean,
    "volume" double precision,
    "capacity" double precision,
    "portionSize" bigint,
    "mass" double precision,
    "marketGroupId" bigint,
    "metaGroupId" bigint,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_type_build_sde_id_idx" ON "sde_type" USING btree ("build", "sdeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sde_type_dogma" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "sdeId" bigint NOT NULL,
    "raw" jsonb NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_type_dogma_build_sde_id_idx" ON "sde_type_dogma" USING btree ("build", "sdeId");


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261119000133693', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261119000133693', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
