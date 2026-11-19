/// The files CCP ships in an SDE build, as the importer knows them.
library;

/// How the importer treats a known file.
enum KnownFileKind {
  /// A file with a typed table; see `typedFiles`. Required.
  typed,

  /// The file holding the `_sde` record with the build number. Required.
  required,

  /// A file stored record by record as raw JSON. Not required.
  plain,
}

/// A file the importer expects in a build.
final class KnownFile {
  /// Creates the entry for [name].
  const KnownFile(this.name, this.kind);

  /// The file's name in the zip, for example `blueprints.jsonl`.
  final String name;

  /// How the importer treats the file.
  final KnownFileKind kind;

  /// Whether a build without this file cannot be imported.
  ///
  /// The required files are the typed set and the file holding the `_sde`
  /// record. A missing file outside them is only reported.
  bool get isRequired => kind != KnownFileKind.plain;
}

/// The name of the file that holds the `_sde` record.
const String sdeRecordFileName = '_sde.jsonl';

/// Every file CCP ships today, found in build 3714173 (102 files).
///
/// A file in a build but not here is new; a file here but not in a build is
/// missing. Add a file here by hand, in a reviewed change, when CCP adds one
/// that Kaname should stop reporting as new.
const List<KnownFile> knownFiles = [
  KnownFile('_sde.jsonl', KnownFileKind.required),
  KnownFile('accountingEntryTypes.jsonl', KnownFileKind.plain),
  KnownFile('agentTypes.jsonl', KnownFileKind.plain),
  KnownFile('agentsInSpace.jsonl', KnownFileKind.plain),
  KnownFile('ancestries.jsonl', KnownFileKind.plain),
  KnownFile('appliedProximityEffects.jsonl', KnownFileKind.plain),
  KnownFile('archetypes.jsonl', KnownFileKind.plain),
  KnownFile('bloodlines.jsonl', KnownFileKind.plain),
  KnownFile('blueprints.jsonl', KnownFileKind.plain),
  KnownFile('categories.jsonl', KnownFileKind.typed),
  KnownFile('certificates.jsonl', KnownFileKind.plain),
  KnownFile('characterAttributes.jsonl', KnownFileKind.plain),
  KnownFile('characterTitles.jsonl', KnownFileKind.plain),
  KnownFile('cloneGrades.jsonl', KnownFileKind.plain),
  KnownFile('compressibleTypes.jsonl', KnownFileKind.plain),
  KnownFile('contrabandTypes.jsonl', KnownFileKind.plain),
  KnownFile('controlTowerResources.jsonl', KnownFileKind.plain),
  KnownFile('corporationActivities.jsonl', KnownFileKind.plain),
  KnownFile('corporationRoleGroups.jsonl', KnownFileKind.plain),
  KnownFile('corporationRoles.jsonl', KnownFileKind.plain),
  KnownFile('dbuffCollections.jsonl', KnownFileKind.plain),
  KnownFile('dogmaAttributeCategories.jsonl', KnownFileKind.typed),
  KnownFile('dogmaAttributes.jsonl', KnownFileKind.typed),
  KnownFile('dogmaEffects.jsonl', KnownFileKind.typed),
  KnownFile('dogmaUnits.jsonl', KnownFileKind.typed),
  KnownFile('dungeons.jsonl', KnownFileKind.plain),
  KnownFile('dynamicItemAttributes.jsonl', KnownFileKind.plain),
  KnownFile('epicArcs.jsonl', KnownFileKind.plain),
  KnownFile('expertSystems.jsonl', KnownFileKind.plain),
  KnownFile('factions.jsonl', KnownFileKind.plain),
  KnownFile('fighterAbilities.jsonl', KnownFileKind.plain),
  KnownFile('fighterAbilitiesByType.jsonl', KnownFileKind.plain),
  KnownFile('freelanceJobSchemas.jsonl', KnownFileKind.plain),
  KnownFile('graphicMaterialSets.jsonl', KnownFileKind.plain),
  KnownFile('graphics.jsonl', KnownFileKind.plain),
  KnownFile('groups.jsonl', KnownFileKind.typed),
  KnownFile('icons.jsonl', KnownFileKind.plain),
  KnownFile('industryActivities.jsonl', KnownFileKind.plain),
  KnownFile('industryAssemblyLines.jsonl', KnownFileKind.plain),
  KnownFile('industryInstallationTypes.jsonl', KnownFileKind.plain),
  KnownFile('industryModifierSources.jsonl', KnownFileKind.plain),
  KnownFile('industryTargetFilters.jsonl', KnownFileKind.plain),
  KnownFile('landmarks.jsonl', KnownFileKind.plain),
  KnownFile('linkWithShip.jsonl', KnownFileKind.plain),
  KnownFile('mapAsteroidBelts.jsonl', KnownFileKind.plain),
  KnownFile('mapConstellations.jsonl', KnownFileKind.typed),
  KnownFile('mapMoons.jsonl', KnownFileKind.plain),
  KnownFile('mapPlanets.jsonl', KnownFileKind.plain),
  KnownFile('mapRegions.jsonl', KnownFileKind.typed),
  KnownFile('mapSecondarySuns.jsonl', KnownFileKind.plain),
  KnownFile('mapSolarSystems.jsonl', KnownFileKind.typed),
  KnownFile('mapStargates.jsonl', KnownFileKind.plain),
  KnownFile('mapStars.jsonl', KnownFileKind.plain),
  KnownFile('marketGroups.jsonl', KnownFileKind.typed),
  KnownFile('masteries.jsonl', KnownFileKind.plain),
  KnownFile('mercenaryTacticalOperations.jsonl', KnownFileKind.plain),
  KnownFile('metaGroups.jsonl', KnownFileKind.typed),
  KnownFile('metenoxMoonDrill.jsonl', KnownFileKind.plain),
  KnownFile('militaryCampaignObjectives.jsonl', KnownFileKind.plain),
  KnownFile('militaryCampaigns.jsonl', KnownFileKind.plain),
  KnownFile('missions.jsonl', KnownFileKind.plain),
  KnownFile('notificationTypes.jsonl', KnownFileKind.plain),
  KnownFile('npcCharacters.jsonl', KnownFileKind.plain),
  KnownFile('npcCorporationDivisions.jsonl', KnownFileKind.plain),
  KnownFile('npcCorporations.jsonl', KnownFileKind.plain),
  KnownFile('npcStations.jsonl', KnownFileKind.plain),
  KnownFile('planetResources.jsonl', KnownFileKind.plain),
  KnownFile('planetSchematics.jsonl', KnownFileKind.plain),
  KnownFile('proximityTrap.jsonl', KnownFileKind.plain),
  KnownFile('races.jsonl', KnownFileKind.plain),
  KnownFile('schoolMap.jsonl', KnownFileKind.plain),
  KnownFile('schools.jsonl', KnownFileKind.plain),
  KnownFile('shipTreeElements.jsonl', KnownFileKind.plain),
  KnownFile('shipTreeFactions.jsonl', KnownFileKind.plain),
  KnownFile('shipTreeGroups.jsonl', KnownFileKind.plain),
  KnownFile('skillPlans.jsonl', KnownFileKind.plain),
  KnownFile('skinLicenses.jsonl', KnownFileKind.plain),
  KnownFile('skinMaterials.jsonl', KnownFileKind.plain),
  KnownFile('skinrComponentCategories.jsonl', KnownFileKind.plain),
  KnownFile('skinrComponentPointValues.jsonl', KnownFileKind.plain),
  KnownFile('skinrComponentRarities.jsonl', KnownFileKind.plain),
  KnownFile('skinrComponents.jsonl', KnownFileKind.plain),
  KnownFile('skinrSlotCategories.jsonl', KnownFileKind.plain),
  KnownFile('skinrSlotConfigurations.jsonl', KnownFileKind.plain),
  KnownFile('skinrSlotNames.jsonl', KnownFileKind.plain),
  KnownFile('skinrSlots.jsonl', KnownFileKind.plain),
  KnownFile('skinrSlotsToMaterials.jsonl', KnownFileKind.plain),
  KnownFile('skinrTierThresholds.jsonl', KnownFileKind.plain),
  KnownFile('skins.jsonl', KnownFileKind.plain),
  KnownFile('sovereigntyUpgrades.jsonl', KnownFileKind.plain),
  KnownFile('stationOperations.jsonl', KnownFileKind.plain),
  KnownFile('stationServices.jsonl', KnownFileKind.plain),
  KnownFile('stationStandingsRestrictions.jsonl', KnownFileKind.plain),
  KnownFile('systemDbuffEmitters.jsonl', KnownFileKind.plain),
  KnownFile('systemWideEffects.jsonl', KnownFileKind.plain),
  KnownFile('translationLanguages.jsonl', KnownFileKind.plain),
  KnownFile('typeBonus.jsonl', KnownFileKind.plain),
  KnownFile('typeDogma.jsonl', KnownFileKind.typed),
  KnownFile('typeElements.jsonl', KnownFileKind.plain),
  KnownFile('typeLists.jsonl', KnownFileKind.plain),
  KnownFile('typeMaterials.jsonl', KnownFileKind.plain),
  KnownFile('types.jsonl', KnownFileKind.typed),
];
