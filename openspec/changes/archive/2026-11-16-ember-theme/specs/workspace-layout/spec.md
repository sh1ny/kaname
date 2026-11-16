# Spec Delta

## MODIFIED Requirements

### Requirement: Packages follow the placement and naming rule
Every package SHALL carry the `kaname_` name prefix and its directory name SHALL equal its package name, except the app. The app SHALL be `app/` (`kaname_app`), pure-Dart shared packages SHALL live in `packages/`, shared Flutter packages in `app_packages/`, tooling packages in `tools/`, and server packages under `server/`.

#### Scenario: Current packages comply
- **WHEN** the workspace check runs after this change
- **THEN** it reports `kaname_app` at `app/`, `kaname_ember_ui` at `app_packages/kaname_ember_ui/`, `kaname_core` at `packages/kaname_core/`, `kaname_tools` at `tools/kaname_tools/`, `kaname_server` at `server/kaname_server/` and `kaname_client` at `server/kaname_client/`, and exits 0

#### Scenario: A misplaced or misnamed package
- **WHEN** a package under `packages/`, `app_packages/`, `server/` or `tools/` is named without the `kaname_` prefix, or its directory name differs from its package name
- **THEN** the workspace check fails and names the package and the rule it breaks
