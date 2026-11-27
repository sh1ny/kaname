BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "esi_call_log_entry" ADD COLUMN "accountExcluded" boolean;
--
-- ACTION CREATE TABLE
--
CREATE TABLE "esi_call_log_exclusion" (
    "id" bigserial PRIMARY KEY,
    "excludedAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "esi_call_log_seal" (
    "id" bigserial PRIMARY KEY,
    "windowEnd" timestamp without time zone NOT NULL
);

--
-- ACTION ALTER TABLE
--
ALTER TABLE "esi_identity" ADD COLUMN "accountId" bigint;
ALTER TABLE "esi_identity" ADD COLUMN "wasDetached" boolean NOT NULL DEFAULT false;
CREATE INDEX "esi_identity_account_character_idx" ON "esi_identity" USING btree ("accountId", "characterId");
--
-- Keep old opt-ins and bearer digests, as well as the existing primary keys
-- and indexes. The old member ID is the signing identity ID, not the account.
ALTER TABLE "esi_scope_opt_in" RENAME COLUMN "memberId" TO "identityId";
ALTER TABLE "esi_session" RENAME COLUMN "memberId" TO "identityId";
ALTER TABLE "esi_session" ADD COLUMN "accountId" bigint;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "member_account" (
    "id" bigserial PRIMARY KEY,
    "mainIdentityId" bigint NOT NULL
);

-- M2 had no links. Preserve its diagnostic account attribution and advance
-- the new sequence before allocating any new member IDs.
INSERT INTO "member_account" ("id", "mainIdentityId")
    SELECT "id", "id" FROM "esi_identity";
SELECT setval(
    pg_get_serial_sequence('member_account', 'id'),
    COALESCE(max("id"), 1),
    count(*) > 0
)
FROM "member_account";
UPDATE "esi_identity" SET "accountId" = "id";

DELETE FROM "esi_session" AS s
    WHERE NOT EXISTS (SELECT 1 FROM "esi_identity" AS i
                      WHERE i."id" = s."identityId");
UPDATE "esi_session" SET "accountId" = "identityId";
ALTER TABLE "esi_session" ALTER COLUMN "accountId" SET NOT NULL;
CREATE INDEX "esi_session_account_idx" ON "esi_session" USING btree ("accountId");

-- There is no prior aggregate to protect on an empty installation. On
-- upgrade, seal the currently eligible M2 window without rewriting receipts.
INSERT INTO "esi_call_log_seal" ("id", "windowEnd")
    SELECT 1, date_trunc('day', (clock_timestamp() AT TIME ZONE 'UTC') - interval '1 minute')
    WHERE EXISTS (SELECT 1 FROM "esi_identity")
       OR EXISTS (SELECT 1 FROM "esi_call_log_entry");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "esi_identity"
    ADD CONSTRAINT "esi_identity_fk_0"
    FOREIGN KEY("accountId")
    REFERENCES "member_account"("id")
    ON DELETE RESTRICT
    ON UPDATE NO ACTION;
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "esi_session"
    ADD CONSTRAINT "esi_session_fk_0"
    FOREIGN KEY("identityId")
    REFERENCES "esi_identity"("id")
    ON DELETE RESTRICT
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "esi_session"
    ADD CONSTRAINT "esi_session_fk_1"
    FOREIGN KEY("accountId")
    REFERENCES "member_account"("id")
    ON DELETE RESTRICT
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "member_account"
    ADD CONSTRAINT "member_account_fk_0"
    FOREIGN KEY("mainIdentityId")
    REFERENCES "esi_identity"("id")
    ON DELETE RESTRICT
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261127093808990-member-accounts', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261127093808990-member-accounts', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
