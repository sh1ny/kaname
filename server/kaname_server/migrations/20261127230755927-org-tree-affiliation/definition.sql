BEGIN;

--
-- Class CharacterAffiliationRow as table character_affiliation
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
-- Class EsiCallLogRow as table esi_call_log_entry
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
    "characterId" bigint,
    "accountExcluded" boolean
);

-- Indexes
CREATE INDEX "esi_call_log_retention_idx" ON "esi_call_log_entry" USING btree ("recordedAt", "id");
CREATE INDEX "esi_call_log_owner_idx" ON "esi_call_log_entry" USING btree ("memberId", "recordedAt", "id");

--
-- Class EsiCallLogExclusionRow as table esi_call_log_exclusion
--
CREATE TABLE "esi_call_log_exclusion" (
    "id" bigserial PRIMARY KEY,
    "excludedAt" timestamp without time zone NOT NULL
);

--
-- Class EsiCallLogSealRow as table esi_call_log_seal
--
CREATE TABLE "esi_call_log_seal" (
    "id" bigserial PRIMARY KEY,
    "windowEnd" timestamp without time zone NOT NULL
);

--
-- Class SsoHolderRow as table esi_holder_assignment
--
CREATE TABLE "esi_holder_assignment" (
    "id" bigserial PRIMARY KEY,
    "characterId" bigint NOT NULL,
    "phase" text NOT NULL,
    "generation" bigint NOT NULL,
    "vaultGeneration" bigint,
    "proofDigest" text,
    "grantFingerprint" text,
    "requestedScopes" json,
    "takeClosures" bigint,
    "lastTakeClosureAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "esi_holder_assignment__characterId__unique_idx" ON "esi_holder_assignment" USING btree ("characterId");

--
-- Class SsoIdentityRow as table esi_identity
--
CREATE TABLE "esi_identity" (
    "id" bigserial PRIMARY KEY,
    "characterId" bigint NOT NULL,
    "owner" text NOT NULL,
    "characterName" text NOT NULL,
    "blocked" boolean NOT NULL,
    "accountId" bigint,
    "wasDetached" boolean NOT NULL DEFAULT false
);

-- Indexes
CREATE UNIQUE INDEX "esi_identity__characterId__unique_idx" ON "esi_identity" USING btree ("characterId");
CREATE INDEX "esi_identity_account_character_idx" ON "esi_identity" USING btree ("accountId", "characterId");

--
-- Class SsoOptInRow as table esi_scope_opt_in
--
CREATE TABLE "esi_scope_opt_in" (
    "id" bigserial PRIMARY KEY,
    "identityId" bigint NOT NULL,
    "owner" text NOT NULL,
    "scopeClass" text NOT NULL,
    "policyFingerprint" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "esi_opt_in_identity_class_idx" ON "esi_scope_opt_in" USING btree ("identityId", "scopeClass");

--
-- Class SsoSessionRow as table esi_session
--
CREATE TABLE "esi_session" (
    "id" bigserial PRIMARY KEY,
    "digest" text NOT NULL,
    "identityId" bigint NOT NULL,
    "accountId" bigint NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "esi_session__digest__unique_idx" ON "esi_session" USING btree ("digest");
CREATE INDEX "esi_session_identity_idx" ON "esi_session" USING btree ("identityId", "expiresAt", "id");
CREATE INDEX "esi_session_account_idx" ON "esi_session" USING btree ("accountId");
CREATE INDEX "esi_session_expiry_idx" ON "esi_session" USING btree ("expiresAt", "id");

--
-- Class EsiTokenVaultRow as table esi_token_vault
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
-- Class MemberAccountRow as table member_account
--
CREATE TABLE "member_account" (
    "id" bigserial PRIMARY KEY,
    "mainIdentityId" bigint NOT NULL
);

--
-- Class SdeAdminOperation as table sde_admin_operation
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
-- Class SdeBuild as table sde_build
--
CREATE TABLE "sde_build" (
    "id" bigserial PRIMARY KEY,
    "build" bigint NOT NULL,
    "state" text NOT NULL,
    "importedAt" timestamp without time zone NOT NULL,
    "activeMarker" boolean,
    "previousMarker" boolean,
    "held" boolean NOT NULL DEFAULT false
);

-- Indexes
CREATE UNIQUE INDEX "sde_build_build_idx" ON "sde_build" USING btree ("build");
CREATE UNIQUE INDEX "sde_build_active_marker_idx" ON "sde_build" USING btree ("activeMarker");
CREATE UNIQUE INDEX "sde_build_previous_marker_idx" ON "sde_build" USING btree ("previousMarker");

--
-- Class SdeBuildDiff as table sde_build_diff
--
CREATE TABLE "sde_build_diff" (
    "id" bigserial PRIMARY KEY,
    "fromBuild" bigint NOT NULL,
    "toBuild" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "outcome" text NOT NULL,
    "failureReason" text,
    "report" jsonb,
    "reportBytes" bigint
);

-- Indexes
CREATE INDEX "sde_build_diff_builds_idx" ON "sde_build_diff" USING btree ("fromBuild", "toBuild");

--
-- Class SdeBuildRevision as table sde_build_revision
--
CREATE TABLE "sde_build_revision" (
    "id" bigserial PRIMARY KEY,
    "revision" bigint NOT NULL
);

--
-- Class SdeBundle as table sde_bundle
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
-- Class SdeBundleBytes as table sde_bundle_bytes
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
-- Class SdeCategory as table sde_category
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
-- Class SdeCheck as table sde_check
--
CREATE TABLE "sde_check" (
    "id" bigserial PRIMARY KEY,
    "checkedAt" timestamp without time zone NOT NULL,
    "trigger" text NOT NULL DEFAULT 'daily'::text,
    "lookupStarted" boolean,
    "lookupStartedAt" timestamp without time zone,
    "latestBuild" bigint,
    "outcome" text NOT NULL,
    "failureReason" text
);

-- Indexes
CREATE INDEX "sde_check_checked_at_idx" ON "sde_check" USING btree ("checkedAt");

--
-- Class SdeConstellation as table sde_constellation
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
-- Class SdeDogmaAttribute as table sde_dogma_attribute
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
-- Class SdeDogmaAttributeCategory as table sde_dogma_attribute_category
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
-- Class SdeDogmaEffect as table sde_dogma_effect
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
-- Class SdeDogmaUnit as table sde_dogma_unit
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
-- Class SdeGroup as table sde_group
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
-- Class SdeImport as table sde_import
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
-- Class SdeMarketGroup as table sde_market_group
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
-- Class SdeMetaGroup as table sde_meta_group
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
-- Class SdeRecord as table sde_record
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
-- Class SdeRegion as table sde_region
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
-- Class SdeSettingWrite as table sde_setting_write
--
CREATE TABLE "sde_setting_write" (
    "id" bigserial PRIMARY KEY,
    "writeId" uuid NOT NULL,
    "autoUpdate" boolean NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sde_setting_write__writeId__unique_idx" ON "sde_setting_write" USING btree ("writeId");

--
-- Class SdeSolarSystem as table sde_solar_system
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
-- Class SdeSwitch as table sde_switch
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
-- Class SdeType as table sde_type
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
-- Class SdeTypeDogma as table sde_type_dogma
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
-- Class CloudStorageEntry as table serverpod_cloud_storage
--
CREATE TABLE "serverpod_cloud_storage" (
    "id" bigserial PRIMARY KEY,
    "storageId" text NOT NULL,
    "path" text NOT NULL,
    "addedTime" timestamp without time zone NOT NULL,
    "expiration" timestamp without time zone,
    "byteData" bytea NOT NULL,
    "verified" boolean NOT NULL,
    "contentType" text,
    "cacheControl" text,
    "contentDisposition" text,
    "contentEncoding" text,
    "customMetadata" text
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_path_idx" ON "serverpod_cloud_storage" USING btree ("storageId", "path");
CREATE INDEX "serverpod_cloud_storage_expiration" ON "serverpod_cloud_storage" USING btree ("expiration");

--
-- Class CloudStorageDirectDownloadEntry as table serverpod_cloud_storage_direct_download
--
CREATE TABLE "serverpod_cloud_storage_direct_download" (
    "id" bigserial PRIMARY KEY,
    "storageId" text NOT NULL,
    "path" text NOT NULL,
    "expiration" timestamp without time zone NOT NULL,
    "authKey" text NOT NULL,
    "downloadFileName" text,
    "contentType" text
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_direct_download_auth_key" ON "serverpod_cloud_storage_direct_download" USING btree ("authKey");
CREATE INDEX "serverpod_cloud_storage_direct_download_expiration" ON "serverpod_cloud_storage_direct_download" USING btree ("expiration");

--
-- Class CloudStorageDirectUploadEntry as table serverpod_cloud_storage_direct_upload
--
CREATE TABLE "serverpod_cloud_storage_direct_upload" (
    "id" bigserial PRIMARY KEY,
    "storageId" text NOT NULL,
    "path" text NOT NULL,
    "expiration" timestamp without time zone NOT NULL,
    "authKey" text NOT NULL,
    "maxFileSize" bigint NOT NULL DEFAULT 10485760,
    "contentLength" bigint,
    "preventOverwrite" boolean NOT NULL DEFAULT false,
    "contentType" text,
    "cacheControl" text,
    "contentDisposition" text,
    "contentEncoding" text,
    "customMetadata" text
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_direct_upload_storage_path" ON "serverpod_cloud_storage_direct_upload" USING btree ("storageId", "path");

--
-- Class FutureCallEntry as table serverpod_future_call
--
CREATE TABLE "serverpod_future_call" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "serializedObject" text,
    "serverId" text NOT NULL,
    "identifier" text,
    "scheduling" json
);

-- Indexes
CREATE INDEX "serverpod_future_call_time_idx" ON "serverpod_future_call" USING btree ("time");
CREATE INDEX "serverpod_future_call_serverId_idx" ON "serverpod_future_call" USING btree ("serverId");
CREATE INDEX "serverpod_future_call_identifier_idx" ON "serverpod_future_call" USING btree ("identifier");

--
-- Class FutureCallClaimEntry as table serverpod_future_call_claim
--
CREATE TABLE "serverpod_future_call_claim" (
    "id" bigserial PRIMARY KEY,
    "futureCallId" bigint,
    "lastHeartbeatTime" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "future_call_unique_idx" ON "serverpod_future_call_claim" USING btree ("futureCallId");

--
-- Class ServerHealthConnectionInfo as table serverpod_health_connection_info
--
CREATE TABLE "serverpod_health_connection_info" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "active" bigint NOT NULL,
    "closing" bigint NOT NULL,
    "idle" bigint NOT NULL,
    "granularity" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_health_connection_info_timestamp_idx" ON "serverpod_health_connection_info" USING btree ("timestamp", "serverId", "granularity");

--
-- Class ServerHealthMetric as table serverpod_health_metric
--
CREATE TABLE "serverpod_health_metric" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "serverId" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "isHealthy" boolean NOT NULL,
    "value" double precision NOT NULL,
    "granularity" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_health_metric_timestamp_idx" ON "serverpod_health_metric" USING btree ("timestamp", "serverId", "name", "granularity");

--
-- Class LogEntry as table serverpod_log
--
CREATE TABLE "serverpod_log" (
    "id" bigserial PRIMARY KEY,
    "sessionLogId" bigint NOT NULL,
    "messageId" bigint,
    "reference" text,
    "serverId" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "logLevel" bigint NOT NULL,
    "message" text NOT NULL,
    "error" text,
    "stackTrace" text,
    "order" bigint NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_log_sessionLogId_idx" ON "serverpod_log" USING btree ("sessionLogId", "order");

--
-- Class MessageLogEntry as table serverpod_message_log
--
CREATE TABLE "serverpod_message_log" (
    "id" bigserial PRIMARY KEY,
    "sessionLogId" bigint NOT NULL,
    "serverId" text NOT NULL,
    "messageId" bigint NOT NULL,
    "endpoint" text NOT NULL,
    "messageName" text NOT NULL,
    "duration" double precision NOT NULL,
    "error" text,
    "stackTrace" text,
    "slow" boolean NOT NULL,
    "order" bigint NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_message_log_sessionLogId_idx" ON "serverpod_message_log" USING btree ("sessionLogId", "order");

--
-- Class MethodInfo as table serverpod_method
--
CREATE TABLE "serverpod_method" (
    "id" bigserial PRIMARY KEY,
    "endpoint" text NOT NULL,
    "method" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_method_endpoint_method_idx" ON "serverpod_method" USING btree ("endpoint", "method");

--
-- Class DatabaseMigrationVersion as table serverpod_migrations
--
CREATE TABLE "serverpod_migrations" (
    "id" bigserial PRIMARY KEY,
    "module" text NOT NULL,
    "version" text NOT NULL,
    "timestamp" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_migrations_ids" ON "serverpod_migrations" USING btree ("module");

--
-- Class QueryLogEntry as table serverpod_query_log
--
CREATE TABLE "serverpod_query_log" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "sessionLogId" bigint NOT NULL,
    "messageId" bigint,
    "query" text NOT NULL,
    "duration" double precision NOT NULL,
    "numRows" bigint,
    "error" text,
    "stackTrace" text,
    "slow" boolean NOT NULL,
    "order" bigint NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_query_log_sessionLogId_idx" ON "serverpod_query_log" USING btree ("sessionLogId", "order");

--
-- Class ReadWriteTestEntry as table serverpod_readwrite_test
--
CREATE TABLE "serverpod_readwrite_test" (
    "id" bigserial PRIMARY KEY,
    "number" bigint NOT NULL
);

--
-- Class RuntimeSettings as table serverpod_runtime_settings
--
CREATE TABLE "serverpod_runtime_settings" (
    "id" bigserial PRIMARY KEY,
    "logSettings" json NOT NULL,
    "logSettingsOverrides" json NOT NULL,
    "logServiceCalls" boolean NOT NULL,
    "logMalformedCalls" boolean NOT NULL
);

--
-- Class SessionLogEntry as table serverpod_session_log
--
CREATE TABLE "serverpod_session_log" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "module" text,
    "endpoint" text,
    "method" text,
    "duration" double precision,
    "numQueries" bigint,
    "slow" boolean,
    "error" text,
    "stackTrace" text,
    "authenticatedUserId" bigint,
    "userId" text,
    "isOpen" boolean,
    "touched" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_session_log_serverid_idx" ON "serverpod_session_log" USING btree ("serverId");
CREATE INDEX "serverpod_session_log_time_idx" ON "serverpod_session_log" USING btree ("time");
CREATE INDEX "serverpod_session_log_touched_idx" ON "serverpod_session_log" USING btree ("touched");
CREATE INDEX "serverpod_session_log_isopen_idx" ON "serverpod_session_log" USING btree ("isOpen");

--
-- Foreign relations for "character_affiliation" table
--
ALTER TABLE ONLY "character_affiliation"
    ADD CONSTRAINT "character_affiliation_fk_0"
    FOREIGN KEY("identityId")
    REFERENCES "esi_identity"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "esi_identity" table
--
ALTER TABLE ONLY "esi_identity"
    ADD CONSTRAINT "esi_identity_fk_0"
    FOREIGN KEY("accountId")
    REFERENCES "member_account"("id")
    ON DELETE RESTRICT
    ON UPDATE NO ACTION;

--
-- Foreign relations for "esi_session" table
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
-- Foreign relations for "member_account" table
--
ALTER TABLE ONLY "member_account"
    ADD CONSTRAINT "member_account_fk_0"
    FOREIGN KEY("mainIdentityId")
    REFERENCES "esi_identity"("id")
    ON DELETE RESTRICT
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_future_call_claim" table
--
ALTER TABLE ONLY "serverpod_future_call_claim"
    ADD CONSTRAINT "serverpod_future_call_claim_fk_0"
    FOREIGN KEY("futureCallId")
    REFERENCES "serverpod_future_call"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_log" table
--
ALTER TABLE ONLY "serverpod_log"
    ADD CONSTRAINT "serverpod_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_message_log" table
--
ALTER TABLE ONLY "serverpod_message_log"
    ADD CONSTRAINT "serverpod_message_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_query_log" table
--
ALTER TABLE ONLY "serverpod_query_log"
    ADD CONSTRAINT "serverpod_query_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
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
