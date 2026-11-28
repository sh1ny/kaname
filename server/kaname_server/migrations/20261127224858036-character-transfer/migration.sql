BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "esi_call_log_entry" ADD COLUMN "ownershipGeneration" bigint NOT NULL DEFAULT 0;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "esi_holder_assignment" ADD COLUMN "takeOwnershipGeneration" bigint NOT NULL DEFAULT 0;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "esi_identity" ADD COLUMN "ownershipGeneration" bigint NOT NULL DEFAULT 0;
ALTER TABLE "esi_identity" ADD COLUMN "awaitingSignIn" boolean NOT NULL DEFAULT false;
ALTER TABLE "esi_identity" ADD COLUMN "transferRuntime" text;
ALTER TABLE "esi_identity" ADD COLUMN "transferAttempt" bigint;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "member_account" ALTER COLUMN "mainIdentityId" DROP NOT NULL;

--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261127224858036-character-transfer', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261127224858036-character-transfer', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
