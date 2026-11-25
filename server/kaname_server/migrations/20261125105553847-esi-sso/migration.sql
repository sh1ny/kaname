BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "esi_holder_assignment" (
    "id" bigserial PRIMARY KEY,
    "characterId" bigint NOT NULL,
    "phase" text NOT NULL,
    "generation" bigint NOT NULL,
    "vaultGeneration" bigint,
    "proofDigest" text,
    "grantFingerprint" text,
    "requestedScopes" json
);

-- Indexes
CREATE UNIQUE INDEX "esi_holder_assignment__characterId__unique_idx" ON "esi_holder_assignment" USING btree ("characterId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "esi_identity" (
    "id" bigserial PRIMARY KEY,
    "characterId" bigint NOT NULL,
    "owner" text NOT NULL,
    "characterName" text NOT NULL,
    "blocked" boolean NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "esi_identity__characterId__unique_idx" ON "esi_identity" USING btree ("characterId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "esi_scope_opt_in" (
    "id" bigserial PRIMARY KEY,
    "memberId" bigint NOT NULL,
    "owner" text NOT NULL,
    "scopeClass" text NOT NULL,
    "policyFingerprint" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "esi_opt_in_identity_class_idx" ON "esi_scope_opt_in" USING btree ("memberId", "scopeClass");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "esi_session" (
    "id" bigserial PRIMARY KEY,
    "digest" text NOT NULL,
    "memberId" bigint NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "esi_session__digest__unique_idx" ON "esi_session" USING btree ("digest");
CREATE INDEX "esi_session_identity_idx" ON "esi_session" USING btree ("memberId", "expiresAt", "id");
CREATE INDEX "esi_session_expiry_idx" ON "esi_session" USING btree ("expiresAt", "id");


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261125105553847-esi-sso', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261125105553847-esi-sso', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
