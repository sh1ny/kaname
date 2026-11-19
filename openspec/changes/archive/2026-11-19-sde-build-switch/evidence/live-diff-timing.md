# Evidence: live diff and switch-delete timing (task 5.4)

- Date: 2026-11-19
- Command: `SDE_LIVE_REPORT=<file> mise run test:sde-live` (the opt-in `sde-live` test in `server/kaname_server/test/integration/static_data/sde_live_test.dart`), run on the development machine against the embedded test Postgres, with the owner's approval. The test passed (`All tests passed!`, about 53 s).
- Second build: CCP's `latest.jsonl` names only the newest build, so the test diffs the imported build against a full-size copy derived from it in SQL, with about 1% of records changed and about 1% removed. The owner accepted this as the "two real builds" of task 5.4.

## Findings

- **A3 holds:** the whole-build diff takes 14.8 s. The slowest statement, `mapMoons.jsonl`, takes 4.7 s, far inside the five-minute `statement_timeout`. No split by key range is needed.
- **First run failed, root cause fixed:** the first run hit the statement timeout at `mapMoons.jsonl`. Right after the import the tables had no statistics (`reltuples = -1`, never analyzed), so the planner estimated one key group per side and chose a nested loop between two materialized CTEs (about 345k x 345k key comparisons). The differ SQL was rewritten so that no statement joins two derived relations: raw files group a `UNION ALL` of both builds by `(key, record)`, and typed tables do the D4 full outer join once. The plan no longer depends on estimates. The production check job diffs right after an import, so it would have hit the same plan.
- **A4 / switch delete:** deleting a whole build in one transaction takes 1.5 s for 679,030 rows.

The test printed this report:

## SDE live import: build 3720952

| Measure | Value |
| --- | ---: |
| Build | 3720952 (active) |
| Zip downloaded | 99765068 bytes (95.1 MiB) |
| Unpacked (sum of entries) | 583946654 bytes (556.9 MiB) |
| Download and open | 5.0 s |
| Whole import | 28.7 s |
| Whole-build diff | 14.8 s |
| Whole-build delete, one transaction | 1.5 s (679030 rows) |

### Diff statements

Each statement must stay within the 5 min `statement_timeout` (A3).

| Statement | Time (ms) | Rows |
| --- | ---: | ---: |
| categories.jsonl | 1 | 7 |
| categories.jsonl fields | 0 | 1 |
| groups.jsonl | 6 | 37 |
| groups.jsonl fields | 3 | 1 |
| types.jsonl | 666 | 1072 |
| types.jsonl fields | 597 | 1 |
| marketGroups.jsonl | 8 | 51 |
| marketGroups.jsonl fields | 6 | 1 |
| metaGroups.jsonl | 0 | 3 |
| dogmaAttributes.jsonl | 8 | 56 |
| dogmaAttributes.jsonl fields | 6 | 1 |
| dogmaAttributeCategories.jsonl | 0 | 3 |
| dogmaEffects.jsonl | 12 | 74 |
| dogmaEffects.jsonl fields | 9 | 1 |
| dogmaUnits.jsonl | 1 | 4 |
| typeDogma.jsonl | 205 | 554 |
| typeDogma.jsonl fields | 184 | 1 |
| mapRegions.jsonl | 2 | 9 |
| mapRegions.jsonl fields | 1 | 1 |
| mapConstellations.jsonl | 3 | 30 |
| mapConstellations.jsonl fields | 2 | 1 |
| mapSolarSystems.jsonl | 36 | 173 |
| mapSolarSystems.jsonl fields | 26 | 1 |
| sde_record files | 413 | 89 |
| _sde.jsonl | 1 | 2 |
| accountingEntryTypes.jsonl | 2 | 6 |
| accountingEntryTypes.jsonl fields | 1 | 1 |
| agentTypes.jsonl | 0 | 3 |
| agentsInSpace.jsonl | 1 | 10 |
| agentsInSpace.jsonl fields | 1 | 1 |
| ancestries.jsonl | 1 | 3 |
| appliedProximityEffects.jsonl | 1 | 6 |
| appliedProximityEffects.jsonl fields | 0 | 1 |
| archetypes.jsonl | 0 | 3 |
| bloodlines.jsonl | 1 | 3 |
| blueprints.jsonl | 63 | 106 |
| blueprints.jsonl fields | 48 | 1 |
| certificates.jsonl | 5 | 6 |
| certificates.jsonl fields | 6 | 1 |
| characterAttributes.jsonl | 1 | 3 |
| characterTitles.jsonl | 1 | 3 |
| cloneGrades.jsonl | 0 | 3 |
| compressibleTypes.jsonl | 1 | 8 |
| compressibleTypes.jsonl fields | 1 | 1 |
| contrabandTypes.jsonl | 0 | 3 |
| controlTowerResources.jsonl | 0 | 3 |
| corporationActivities.jsonl | 1 | 3 |
| corporationRoleGroups.jsonl | 0 | 3 |
| corporationRoles.jsonl | 0 | 3 |
| dbuffCollections.jsonl | 3 | 10 |
| dbuffCollections.jsonl fields | 2 | 1 |
| dungeons.jsonl | 13 | 34 |
| dungeons.jsonl fields | 11 | 1 |
| dynamicItemAttributes.jsonl | 4 | 12 |
| dynamicItemAttributes.jsonl fields | 2 | 1 |
| epicArcs.jsonl | 0 | 3 |
| expertSystems.jsonl | 1 | 3 |
| factions.jsonl | 2 | 3 |
| fighterAbilities.jsonl | 0 | 3 |
| fighterAbilitiesByType.jsonl | 0 | 3 |
| freelanceJobSchemas.jsonl | 0 | 3 |
| graphicMaterialSets.jsonl | 8 | 22 |
| graphicMaterialSets.jsonl fields | 5 | 1 |
| graphics.jsonl | 19 | 126 |
| graphics.jsonl fields | 14 | 1 |
| icons.jsonl | 13 | 102 |
| icons.jsonl fields | 11 | 1 |
| industryActivities.jsonl | 0 | 3 |
| industryAssemblyLines.jsonl | 2 | 6 |
| industryAssemblyLines.jsonl fields | 2 | 1 |
| industryInstallationTypes.jsonl | 1 | 6 |
| industryInstallationTypes.jsonl fields | 0 | 1 |
| industryModifierSources.jsonl | 1 | 8 |
| industryModifierSources.jsonl fields | 1 | 1 |
| industryTargetFilters.jsonl | 0 | 3 |
| landmarks.jsonl | 2 | 3 |
| linkWithShip.jsonl | 0 | 3 |
| mapAsteroidBelts.jsonl | 320 | 822 |
| mapAsteroidBelts.jsonl fields | 296 | 1 |
| mapMoons.jsonl | 4665 | 2003 |
| mapMoons.jsonl fields | 3537 | 1 |
| mapPlanets.jsonl | 780 | 1372 |
| mapPlanets.jsonl fields | 726 | 1 |
| mapSecondarySuns.jsonl | 4 | 24 |
| mapSecondarySuns.jsonl fields | 4 | 1 |
| mapStargates.jsonl | 58 | 282 |
| mapStargates.jsonl fields | 56 | 1 |
| mapStars.jsonl | 30 | 164 |
| mapStars.jsonl fields | 28 | 1 |
| masteries.jsonl | 3 | 12 |
| masteries.jsonl fields | 3 | 1 |
| mercenaryTacticalOperations.jsonl | 0 | 3 |
| metenoxMoonDrill.jsonl | 0 | 3 |
| militaryCampaignObjectives.jsonl | 36 | 3 |
| militaryCampaigns.jsonl | 8 | 2 |
| missions.jsonl | 398 | 60 |
| missions.jsonl fields | 558 | 1 |
| notificationTypes.jsonl | 1 | 8 |
| notificationTypes.jsonl fields | 1 | 1 |
| npcCharacters.jsonl | 82 | 230 |
| npcCharacters.jsonl fields | 104 | 1 |
| npcCorporationDivisions.jsonl | 1 | 3 |
| npcCorporations.jsonl | 14 | 8 |
| npcCorporations.jsonl fields | 17 | 1 |
| npcStations.jsonl | 20 | 108 |
| npcStations.jsonl fields | 29 | 1 |
| planetResources.jsonl | 69 | 518 |
| planetResources.jsonl fields | 95 | 1 |
| planetSchematics.jsonl | 1 | 3 |
| proximityTrap.jsonl | 0 | 3 |
| races.jsonl | 0 | 3 |
| schoolMap.jsonl | 0 | 3 |
| schools.jsonl | 1 | 3 |
| shipTreeElements.jsonl | 0 | 3 |
| shipTreeFactions.jsonl | 0 | 3 |
| shipTreeGroups.jsonl | 1 | 3 |
| skillPlans.jsonl | 3 | 3 |
| skinLicenses.jsonl | 25 | 242 |
| skinLicenses.jsonl fields | 39 | 1 |
| skinMaterials.jsonl | 3 | 20 |
| skinMaterials.jsonl fields | 4 | 1 |
| skinrComponentCategories.jsonl | 0 | 3 |
| skinrComponentPointValues.jsonl | 0 | 3 |
| skinrComponentRarities.jsonl | 0 | 3 |
| skinrComponents.jsonl | 3 | 16 |
| skinrComponents.jsonl fields | 3 | 1 |
| skinrSlotCategories.jsonl | 0 | 3 |
| skinrSlotConfigurations.jsonl | 0 | 3 |
| skinrSlotNames.jsonl | 0 | 3 |
| skinrSlots.jsonl | 0 | 3 |
| skinrSlotsToMaterials.jsonl | 0 | 3 |
| skinrTierThresholds.jsonl | 0 | 3 |
| skins.jsonl | 18 | 144 |
| skins.jsonl fields | 29 | 1 |
| sovereigntyUpgrades.jsonl | 1 | 3 |
| stationOperations.jsonl | 1 | 3 |
| stationServices.jsonl | 0 | 3 |
| stationStandingsRestrictions.jsonl | 0 | 3 |
| systemDbuffEmitters.jsonl | 0 | 3 |
| systemWideEffects.jsonl | 0 | 6 |
| systemWideEffects.jsonl fields | 0 | 1 |
| translationLanguages.jsonl | 0 | 2 |
| typeBonus.jsonl | 20 | 16 |
| typeBonus.jsonl fields | 36 | 1 |
| typeElements.jsonl | 2 | 12 |
| typeElements.jsonl fields | 2 | 1 |
| typeLists.jsonl | 2 | 12 |
| typeLists.jsonl fields | 2 | 1 |
| typeMaterials.jsonl | 47 | 196 |
| typeMaterials.jsonl fields | 62 | 1 |
| **Total** | **14794** | |

Report: 102 files, 2 added, 6877 removed, 6737 changed, 2 key lists cut off.

### Whole-build delete statements

| Statement | Time (ms) | Rows |
| --- | ---: | ---: |
| sde_category | 0 | 48 |
| sde_group | 1 | 1633 |
| sde_type | 493 | 53941 |
| sde_market_group | 3 | 2125 |
| sde_meta_group | 0 | 15 |
| sde_dogma_attribute | 2 | 2929 |
| sde_dogma_attribute_category | 0 | 37 |
| sde_dogma_effect | 3 | 3499 |
| sde_dogma_unit | 0 | 60 |
| sde_type_dogma | 28 | 27295 |
| sde_region | 1 | 114 |
| sde_constellation | 1 | 1184 |
| sde_solar_system | 15 | 8490 |
| sde_record | 993 | 577659 |
| sde_build_diff | 0 | 0 |
| sde_build | 0 | 1 |
| **Total** | **1549** | |

### Resource bounds

| Cap | Measured | Limit | Result |
| --- | ---: | ---: | --- |
| Download size | 99765068 bytes | 1 GiB | pass |
| Largest entry, unpacked | 223976066 bytes | 4 GiB | pass |
| All entries, unpacked | 583946654 bytes | 8 GiB | pass |
| Longest line | 99390 bytes | 16 MiB | pass |
| Whole import | 28.7 s | 2 h | pass |

### Records per file (679029 records in 102 files)

| File | Records |
| --- | ---: |
| _sde.jsonl | 1 |
| accountingEntryTypes.jsonl | 177 |
| agentTypes.jsonl | 13 |
| agentsInSpace.jsonl | 360 |
| ancestries.jsonl | 43 |
| appliedProximityEffects.jsonl | 119 |
| archetypes.jsonl | 36 |
| bloodlines.jsonl | 18 |
| blueprints.jsonl | 5136 |
| categories.jsonl | 48 |
| certificates.jsonl | 139 |
| characterAttributes.jsonl | 5 |
| characterTitles.jsonl | 148 |
| cloneGrades.jsonl | 4 |
| compressibleTypes.jsonl | 220 |
| contrabandTypes.jsonl | 8 |
| controlTowerResources.jsonl | 44 |
| corporationActivities.jsonl | 20 |
| corporationRoleGroups.jsonl | 9 |
| corporationRoles.jsonl | 55 |
| dbuffCollections.jsonl | 373 |
| dogmaAttributeCategories.jsonl | 37 |
| dogmaAttributes.jsonl | 2929 |
| dogmaEffects.jsonl | 3499 |
| dogmaUnits.jsonl | 60 |
| dungeons.jsonl | 1517 |
| dynamicItemAttributes.jsonl | 441 |
| epicArcs.jsonl | 21 |
| expertSystems.jsonl | 59 |
| factions.jsonl | 27 |
| fighterAbilities.jsonl | 36 |
| fighterAbilitiesByType.jsonl | 94 |
| freelanceJobSchemas.jsonl | 1 |
| graphicMaterialSets.jsonl | 968 |
| graphics.jsonl | 6113 |
| groups.jsonl | 1633 |
| icons.jsonl | 4908 |
| industryActivities.jsonl | 6 |
| industryAssemblyLines.jsonl | 146 |
| industryInstallationTypes.jsonl | 102 |
| industryModifierSources.jsonl | 220 |
| industryTargetFilters.jsonl | 18 |
| landmarks.jsonl | 45 |
| linkWithShip.jsonl | 3 |
| mapAsteroidBelts.jsonl | 40928 |
| mapConstellations.jsonl | 1184 |
| mapMoons.jsonl | 344457 |
| mapPlanets.jsonl | 68407 |
| mapRegions.jsonl | 114 |
| mapSecondarySuns.jsonl | 1038 |
| mapSolarSystems.jsonl | 8490 |
| mapStargates.jsonl | 13982 |
| mapStars.jsonl | 8089 |
| marketGroups.jsonl | 2125 |
| masteries.jsonl | 496 |
| mercenaryTacticalOperations.jsonl | 3 |
| metaGroups.jsonl | 15 |
| metenoxMoonDrill.jsonl | 1 |
| militaryCampaignObjectives.jsonl | 192 |
| militaryCampaigns.jsonl | 8 |
| missions.jsonl | 2892 |
| notificationTypes.jsonl | 297 |
| npcCharacters.jsonl | 11399 |
| npcCorporationDivisions.jsonl | 10 |
| npcCorporations.jsonl | 283 |
| npcStations.jsonl | 5211 |
| planetResources.jsonl | 25798 |
| planetSchematics.jsonl | 68 |
| proximityTrap.jsonl | 24 |
| races.jsonl | 11 |
| schoolMap.jsonl | 12 |
| schools.jsonl | 23 |
| shipTreeElements.jsonl | 30 |
| shipTreeFactions.jsonl | 17 |
| shipTreeGroups.jsonl | 52 |
| skillPlans.jsonl | 40 |
| skinLicenses.jsonl | 11922 |
| skinMaterials.jsonl | 884 |
| skinrComponentCategories.jsonl | 3 |
| skinrComponentPointValues.jsonl | 3 |
| skinrComponentRarities.jsonl | 6 |
| skinrComponents.jsonl | 630 |
| skinrSlotCategories.jsonl | 3 |
| skinrSlotConfigurations.jsonl | 4 |
| skinrSlotNames.jsonl | 8 |
| skinrSlots.jsonl | 8 |
| skinrSlotsToMaterials.jsonl | 16 |
| skinrTierThresholds.jsonl | 49 |
| skins.jsonl | 7093 |
| sovereigntyUpgrades.jsonl | 49 |
| stationOperations.jsonl | 70 |
| stationServices.jsonl | 27 |
| stationStandingsRestrictions.jsonl | 1 |
| systemDbuffEmitters.jsonl | 85 |
| systemWideEffects.jsonl | 114 |
| translationLanguages.jsonl | 8 |
| typeBonus.jsonl | 699 |
| typeDogma.jsonl | 27295 |
| typeElements.jsonl | 443 |
| typeLists.jsonl | 477 |
| typeMaterials.jsonl | 9636 |
| types.jsonl | 53941 |

### Drift

None: the build matches the known files and fields.

### Bad records

None.

### Known ids

3 checked, all found.

### Industry and logistics field check

30 of 30 declared fields present: no gap.
