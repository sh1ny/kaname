# Spec Delta

## MODIFIED Requirements

### Requirement: A stale dependency section is detectable
The notices task SHALL have a check mode that writes nothing and fails when the dependency section differs from what the current lockfile would generate, or when a vendored source is missing from the hand-written sections. CI SHALL run the check mode on every pull request and push to `main`.

#### Scenario: Up to date
- **WHEN** the check mode runs right after the notices task
- **THEN** it exits 0 and writes nothing

#### Scenario: Lockfile changed without regenerating
- **WHEN** a dependency is added or upgraded and the notices task is not rerun
- **THEN** the check mode exits non-zero and names the packages that are missing, extra or at a different version

#### Scenario: Stale notices in a pull request
- **WHEN** a pull request changes `pubspec.lock` without regenerating `THIRD_PARTY_NOTICES`
- **THEN** CI fails on that pull request with the check mode's message
