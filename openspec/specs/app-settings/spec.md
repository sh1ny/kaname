# app-settings Specification

## Purpose
Defines the app's Settings screen: the user's theme choice and how it is kept across restarts, the server section's place in it, and the About section with the app's licence page.

## Requirements

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

### Requirement: The user chooses System, Dark or Light
The Appearance section SHALL offer exactly three theme choices: System, Dark and Light. System SHALL follow the operating system's light or dark setting. Dark and Light SHALL show the Ember dark or light theme whatever the operating system's setting. A change SHALL take effect on the next frame, with no animated blend of surfaces.

#### Scenario: Choose Light on a dark system
- **WHEN** the operating system is set to dark and the user chooses Light
- **THEN** the app shows the Ember light canvas on the next frame

#### Scenario: System follows a later OS change
- **WHEN** the choice is System and the operating system switches from dark to light while the app runs
- **THEN** the app shows the Ember light canvas on the next frame

### Requirement: The theme choice survives a restart
The app SHALL keep the user's theme choice on the device and SHALL apply it from the first frame of the next start. With no stored choice, or with a stored value it does not recognise, the app SHALL use System and SHALL NOT fail to start.

#### Scenario: Restart after choosing Dark
- **WHEN** the user chooses Dark, closes the app and starts it again on a light system
- **THEN** the first frame shows the Ember dark canvas and Settings shows Dark selected

#### Scenario: Unreadable stored value
- **WHEN** the device's stored theme value is missing, empty or not one of the three choices
- **THEN** the app starts with System selected and shows no error

#### Scenario: Storage fails to save
- **WHEN** saving the choice fails
- **THEN** the chosen theme still applies for the running session, and the app shows a non-blocking message that the choice was not saved

### Requirement: About shows the version and the licence page
The About section SHALL show the app's version and SHALL open the app's licence page, which lists the app's packages and the bundled fonts with their licence text.

#### Scenario: Open licences
- **WHEN** the user opens the licence page from About
- **THEN** the page lists Geist and Literata with their licence text

#### Scenario: Back from licences
- **WHEN** the user leaves the licence page with the back control or the browser's back button
- **THEN** the Settings screen is shown again with its theme choice unchanged
