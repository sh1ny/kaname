# Spec Delta

## MODIFIED Requirements

### Requirement: Settings has Appearance, Server and About sections
The Settings screen SHALL show four sections in this order: Appearance (the theme choice), Server (the server status, as the app-server-connection capability defines), Static data (as the static-data-settings capability defines) and About (the app's version and a way to open the licence page).

#### Scenario: Open Settings
- **WHEN** the user opens Settings on any platform
- **THEN** the Appearance, Server, Static data and About sections appear in that order

#### Scenario: Narrow window
- **WHEN** Settings is shown at 390 pixels wide
- **THEN** the four sections stack in one column with no horizontal scrolling and no overflow

#### Scenario: No server configured
- **WHEN** a desktop build without a server address opens Settings
- **THEN** the Static data section still appears between Server and About
