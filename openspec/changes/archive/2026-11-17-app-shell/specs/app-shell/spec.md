# Spec Delta

## Purpose

Defines the app's adaptive frame that every module plugs into: its regions and breakpoints, mobile navigation, the docked inspector, the module-slot registry, routes and deep links, and localised shell text.

## ADDED Requirements

### Requirement: Wide windows show the full desktop frame
When the app's window is wider than 1080 logical pixels, the shell SHALL show a top bar and a status bar across the full width, and between them an icon rail, a contextual sidebar, the main column and, while open, a docked inspector. Docked regions are separated by tone and a hairline and cast no shadow.

#### Scenario: Desktop width
- **WHEN** the app runs in a window 1440 logical pixels wide
- **THEN** the top bar, rail, sidebar, main column and status bar are all visible, and no region uses a bottom navigation bar or a drawer

#### Scenario: Window narrowed across the breakpoint
- **WHEN** a 1440-pixel window with the inspector open is narrowed to 1000 pixels
- **THEN** the rail and sidebar stay docked, the inspector is shown as an overlay sheet instead of a docked column, and the main column's content stays mounted with its state

### Requirement: Medium windows show the inspector as an overlay
When the window is wider than 760 and at most 1080 logical pixels, the shell SHALL keep the rail and sidebar docked and SHALL show the inspector, while open, as an overlay sheet from the right over a scrim.

#### Scenario: Inspector opened at medium width
- **WHEN** the window is 900 pixels wide and the user opens the inspector
- **THEN** the inspector appears as a sheet from the right over a scrim, and the main column keeps its width

#### Scenario: Scrim dismisses the sheet
- **WHEN** the inspector sheet is open at 900 pixels and the user taps the scrim
- **THEN** the sheet closes and the main column's content is unchanged

### Requirement: Narrow windows use bottom navigation and a sidebar drawer
When the window is at most 760 logical pixels wide, the shell SHALL replace the rail with a bottom navigation bar that holds the top-level slots, and SHALL show the contextual sidebar only as a drawer behind a scrim. The inspector opens as an overlay sheet.

#### Scenario: Phone width
- **WHEN** the app runs at 390 pixels wide
- **THEN** a bottom navigation bar lists Home, Personal, Organisation and Settings, no rail is shown, and the sidebar is hidden until the drawer is opened

#### Scenario: Drawer closes on navigation
- **WHEN** the drawer is open at 390 pixels and the user picks a destination in the bottom bar
- **THEN** the drawer closes and the chosen destination is shown

### Requirement: The docked inspector opens and closes without replacing the subject
The shell SHALL offer an inspector that the user can open and close. Opening, closing or switching it between docked and overlay SHALL NOT unmount the main column's content. Closing it SHALL return keyboard focus to the control that opened it. In M0 the inspector holds no content beyond an empty state.

#### Scenario: Open and close with the keyboard
- **WHEN** the user opens the inspector with its toggle and then closes it with the inspector's close control
- **THEN** keyboard focus returns to the toggle, and the main column's content is the same widget state as before

#### Scenario: Opener gone when closing
- **WHEN** the inspector is closed after the control that opened it is no longer on screen (for example after a breakpoint change)
- **THEN** focus moves to the main column and no error is raised

### Requirement: Panels move with one motion and honour reduced motion
Opening and closing the inspector and its overlay sheet, and opening and closing the sidebar drawer, SHALL animate over 200ms with Ember's panel easing. When the platform asks for reduced motion, these SHALL complete within one frame. Other shell changes, such as selecting a destination, SHALL take effect on the next frame.

#### Scenario: Normal motion
- **WHEN** the user opens the docked inspector with no reduced-motion setting
- **THEN** the inspector reaches its full 352-pixel width 200ms later, not before

#### Scenario: Reduced motion
- **WHEN** the platform reports that animations should be disabled and the user opens the inspector
- **THEN** the inspector is fully open on the next frame

### Requirement: Module slots come from one registry
The shell SHALL build its rail, bottom bar and routes from one registry of module slots, each with a unique id, a label, an icon and a route path. M0 SHALL register Home, Personal and Organisation as empty slots, plus Settings. A registry with a duplicate id or route path SHALL be refused at startup with an error naming the duplicate.

#### Scenario: Registered slots appear in order
- **WHEN** the app starts with the M0 registry
- **THEN** the rail lists Home, Personal and Organisation in that order, with Settings at the rail's foot, and each empty slot shows an empty state naming the slot

#### Scenario: Duplicate slot
- **WHEN** the registry holds two slots with the same id or the same route path
- **THEN** the app fails at startup with an error that names the duplicate id or path, before any screen is shown

### Requirement: Every destination has a route and deep links work
Each slot and the Settings screen SHALL have its own URL path. On the web, the browser address SHALL show the current destination's path, opening a valid path directly SHALL show that destination, and the browser's back button SHALL return to the previous destination. An unknown path SHALL show a not-found state inside the shell with a way back to Home.

#### Scenario: Deep link on the web
- **WHEN** the web app is opened directly at the Settings path
- **THEN** the shell shows the Settings screen with the Settings destination selected

#### Scenario: Unknown path
- **WHEN** the web app is opened at a path no destination owns
- **THEN** the shell shows a not-found state that names no internal detail, with a control that leads to Home, and no exception is reported

### Requirement: Shell text is localised
Every user-visible string in the shell, its slots' empty states and the Settings screen SHALL come from the app's localisation resources. M0 SHALL ship English only and SHALL use English when the device's locale is not supported.

#### Scenario: English device
- **WHEN** the app runs with the device locale `en-GB`
- **THEN** destination labels and empty states show their English text

#### Scenario: Unsupported locale
- **WHEN** the app runs with the device locale `ja-JP`
- **THEN** the shell shows the English text and no missing-translation placeholder or error appears

### Requirement: Shell controls are reachable by keyboard and screen reader
Every rail item, bottom-bar item, the drawer and inspector toggles and the inspector's close control SHALL be reachable with the keyboard, SHALL show the Ember focus ring while focused, and SHALL carry a semantic label. The selected destination SHALL be announced as selected.

#### Scenario: Tab through the rail
- **WHEN** the user moves keyboard focus through the rail on a wide window
- **THEN** each rail item takes focus in order and shows the focus ring, and the selected one reports a selected state to assistive technology

#### Scenario: Icon-only control without a label
- **WHEN** the shell's widget tests check every icon-only shell control's semantics
- **THEN** each has a non-empty label, and a control without one fails the test
