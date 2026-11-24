BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "esi_token_vault" (
    "id" bigserial PRIMARY KEY,
    "characterId" bigint NOT NULL,
    "holderKind" text NOT NULL,
    "holderId" text NOT NULL,
    "generation" bigint NOT NULL,
    "status" text NOT NULL,
    "sealedCredential" text,
    "fence" bigint NOT NULL,
    "leaseUntil" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "esi_token_vault__characterId__unique_idx" ON "esi_token_vault" USING btree ("characterId");


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261124224437322-esi-token-vault', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261124224437322-esi-token-vault', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
