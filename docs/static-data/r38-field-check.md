# R38: industry and logistics fields in SDE build 3714173

- Build: 3714173
- Date: 2026-11-19

| File | Field path | Purpose | Status | Records |
| --- | --- | --- | --- | ---: |
| types.jsonl | `volume` | M22 freight: the volume of an item in cargo | present | 47684 |
| types.jsonl | `packagedVolume` | M22 freight: the volume of a repackaged ship or item | present | 47684 |
| types.jsonl | `capacity` | M22 freight: the cargo capacity of a hauler or container | present | 10204 |
| types.jsonl | `portionSize` | M20 reprocessing: the batch size of one reprocessing run | present | 53927 |
| blueprints.jsonl | `activities.manufacturing.materials[]` | M18 build planner: the materials of a manufacturing job | present | 4909 |
| blueprints.jsonl | `activities.manufacturing.products[]` | M18 build planner: what a manufacturing job produces | present | 4903 |
| blueprints.jsonl | `activities.manufacturing.skills[]` | M18 build planner: the skills a manufacturing job needs | present | 4789 |
| blueprints.jsonl | `activities.manufacturing.time` | M18 cost model: the base time of a manufacturing job | present | 4926 |
| blueprints.jsonl | `activities.invention.materials[]` | M19 invention: the datacores and other inputs of an invention job | present | 1116 |
| blueprints.jsonl | `activities.invention.products[]` | M19 invention: the blueprints an invention job can produce | present | 1113 |
| blueprints.jsonl | `activities.invention.products[].probability` | M19 invention: the chance that an invention job succeeds | present | 1105 |
| blueprints.jsonl | `activities.invention.skills[]` | M19 invention: the skills an invention job needs | present | 1116 |
| blueprints.jsonl | `activities.invention.time` | M19 invention: the base time of an invention job | present | 1117 |
| blueprints.jsonl | `activities.reaction.materials[]` | M18 build planner: the inputs of a reaction job | present | 120 |
| blueprints.jsonl | `activities.reaction.products[]` | M18 build planner: what a reaction job produces | present | 120 |
| blueprints.jsonl | `activities.reaction.time` | M18 cost model: the base time of a reaction job | present | 120 |
| blueprints.jsonl | `activities.copying.time` | M18 jobs: the base time of a copying job | present | 4380 |
| blueprints.jsonl | `activities.research_material.time` | M18 jobs: the base time of a material efficiency research job | present | 4380 |
| blueprints.jsonl | `activities.research_time.time` | M18 jobs: the base time of a time efficiency research job | present | 4380 |
| blueprints.jsonl | `maxProductionLimit` | M18 jobs: the most runs of a blueprint copy | present | 5136 |
| typeMaterials.jsonl | `materials[].materialTypeID` | M20 reprocessing: what an item reprocesses into | present | 9626 |
| typeMaterials.jsonl | `materials[].quantity` | M20 reprocessing: how much of each material an item yields | present | 9626 |
| planetSchematics.jsonl | `cycleTime` | M19 PI dashboard: the cycle time of a schematic | present | 68 |
| planetSchematics.jsonl | `types[].isInput` | M19 PI dashboard: which items a schematic consumes and makes | present | 68 |
| planetSchematics.jsonl | `types[].quantity` | M19 PI dashboard: how much a schematic consumes and makes | present | 68 |
| mapStargates.jsonl | `destination.solarSystemID` | M22 freight: the system on the other side of a stargate, for routes | present | 13982 |
| mapSolarSystems.jsonl | `position.x` | M22 freight: the system position, for distances (x) | present | 8490 |
| mapSolarSystems.jsonl | `position.y` | M22 freight: the system position, for distances (y) | present | 8490 |
| mapSolarSystems.jsonl | `position.z` | M22 freight: the system position, for distances (z) | present | 8490 |
| mapSolarSystems.jsonl | `securityStatus` | M22 freight: the security of a system, for route risk | present | 8490 |

Verdict: no gap. All 30 declared fields are present in build 3714173.
