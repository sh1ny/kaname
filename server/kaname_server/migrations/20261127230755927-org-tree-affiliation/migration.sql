BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "character_affiliation" (
    "id" bigserial PRIMARY KEY,
    "identityId" bigint NOT NULL,
    "corporationId" bigint NOT NULL,
    "allianceId" bigint,
    "observedAt" timestamp without time zone NOT NULL,
    "lookupOrder" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "character_affiliation_identity_idx" ON "character_affiliation" USING btree ("identityId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "character_affiliation"
    ADD CONSTRAINT "character_affiliation_fk_0"
    FOREIGN KEY("identityId")
    REFERENCES "esi_identity"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR kaname
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('kaname', '20261127230755927-org-tree-affiliation', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261127230755927-org-tree-affiliation', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();


COMMIT;
