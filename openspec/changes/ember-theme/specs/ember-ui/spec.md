# Spec Delta

## Purpose

Kaname's Flutter design-system package applies the Ember design system to the app: tokens generated from the brand source, bundled fonts and their licences, dark and light themes, and Ember-styled Material controls with guaranteed contrast and visible keyboard focus.

## ADDED Requirements

### Requirement: Tokens are generated from the brand source
The design-system package's tokens (colours for both rooms, shadows, type styles, radii, spacing, sizes and motion) SHALL be generated from `brand/tokens.json` and never edited by hand. A check, run by the all-checks task and in CI, SHALL fail when the committed generated tokens differ from what `brand/tokens.json` produces.

#### Scenario: Generated tokens are current
- **WHEN** the token generator runs on an unchanged `brand/tokens.json` and the all-checks task runs
- **THEN** the generator changes no committed file, and the token check exits 0

#### Scenario: Tokens edited without regenerating
- **WHEN** a value in `brand/tokens.json` changes and the generator is not rerun
- **THEN** the token check exits non-zero, names the stale generated file and says to run the generator

#### Scenario: Generated file edited by hand
- **WHEN** the committed generated token file is edited by hand
- **THEN** the token check exits non-zero and names that file

### Requirement: Every colour role exists in both rooms
Every colour role in `brand/tokens.json` SHALL have a dark and a light value, and the package SHALL expose each role under one name in both themes. The generator SHALL refuse a token file in which a colour role lacks either value or holds a colour it cannot parse, and SHALL then write nothing.

#### Scenario: Both rooms carry every role
- **WHEN** the dark and the light theme are built
- **THEN** each exposes every colour role named in `brand/tokens.json`, with that role's dark or light value

#### Scenario: A role without a light value
- **WHEN** a colour role in `brand/tokens.json` has a dark value and no light value
- **THEN** the generator exits non-zero, names the role and the missing room, and leaves the generated files unchanged

#### Scenario: An unparseable colour
- **WHEN** a colour value is neither `#rrggbb` nor `rgba(r,g,b,a)`
- **THEN** the generator exits non-zero, names the role and the value, and leaves the generated files unchanged

### Requirement: Fonts are bundled and never fetched from another host
The package SHALL bundle Geist and Literata (upright and italic) as font assets covering weights 400 to 600. Every Ember type style SHALL resolve to a bundled family, and the package SHALL offer no style that depends on a system font. The app SHALL NOT fetch a font from any host other than its own on any platform.

#### Scenario: Type styles use bundled families
- **WHEN** a test inspects each Ember type style the package offers
- **THEN** each style's family is a font asset declared by the package, and no style names a system font family such as `ui-monospace`

#### Scenario: A font asset is missing
- **WHEN** a font file declared by the package is absent from the package
- **THEN** the package's tests fail and name the missing font file

### Requirement: The web build loads no engine or font files from third-party hosts
The app's release web build SHALL include Flutter's rendering engine files in its own output, and SHALL configure the engine to load fallback fonts only from an address on the app's own origin. The local web build task, the CI web build and the stack's build SHALL each produce such a build and check its output.

#### Scenario: Self-contained web build
- **WHEN** the web build task runs
- **THEN** the build output holds the engine's `.wasm` files under its own directory, its build configuration enables the local engine, and its loader configuration sets the fallback-font address to a path on the app's own origin

#### Scenario: A build that depends on the CDN
- **WHEN** a web build is produced without the local engine, without its engine files, or with the fallback-font address unset or on another host
- **THEN** the web build check exits non-zero and names what is missing or which address it found

#### Scenario: A glyph no bundled font covers
- **WHEN** the web app renders a character that neither Geist nor Literata covers
- **THEN** it requests nothing from any other host, and the character shows as an empty box

### Requirement: Font licences ship with the app
The package SHALL bundle the SIL Open Font License text of each font family and register it with the app's licence registry, so that the app's licence page lists Geist and Literata with their full licence text on every platform.

#### Scenario: Licence page lists the fonts
- **WHEN** the app's licence entries are collected
- **THEN** there is an entry for Geist and one for Literata, each holding the full OFL-1.1 text with that family's copyright line

#### Scenario: A licence text is missing
- **WHEN** a font family's licence file is absent from the package
- **THEN** the package's tests fail and name the family and the missing licence file

### Requirement: The package provides a dark and a light theme
The package SHALL provide an Ember dark theme and an Ember light theme for the app. Each SHALL carry Ember's colour roles that Material has no slot for, readable from the theme by a widget. A widget that asks for those roles under a theme that is not Ember SHALL get an error saying the Ember theme is not installed.

#### Scenario: Themes in both rooms
- **WHEN** a widget is built under the Ember dark theme and then under the Ember light theme
- **THEN** it reads the canvas, ink and accent roles with the dark values in the first case and the light values in the second

#### Scenario: Roles read without the Ember theme
- **WHEN** a widget asks for Ember's colour roles under a theme that is not Ember
- **THEN** it gets an error whose message says the Ember theme is not installed, not a null value

### Requirement: The app follows the system theme until the user chooses
The app SHALL use the Ember dark and light themes and SHALL show the one that matches the operating system's light or dark setting while the user has not chosen a theme. Surfaces and Ember-styled controls SHALL switch instantly, with no animated blend. Text that inherits Material's default text style blends over Material's 200ms, text-field borders and labels over Material's 167ms, and chip outlines over Material's 75ms; all three are recorded exceptions.

#### Scenario: Dark system setting
- **WHEN** the app starts with the platform brightness set to dark
- **THEN** it renders with the Ember dark theme's canvas colour

#### Scenario: System setting changes while running
- **WHEN** the platform brightness changes from dark to light while the app runs
- **THEN** the next frame shows the Ember light theme's canvas colour, with no intermediate colour and no restart

### Requirement: Material controls take Ember's shapes and states
Buttons (default, primary and quiet), icon buttons, chips, text fields, menus, tooltips and snackbars SHALL take Ember's sizes, shapes and colours in both themes. Pressing controls (buttons, chips, snackbars) are pills; containers have soft corners. No control paints a splash. Buttons, icon buttons and menu items change state on the next frame; text-field, chip, snackbar and tooltip transitions are Material's own.

#### Scenario: Specimen matches the goldens
- **WHEN** the golden test renders the control specimen in the dark and the light theme
- **THEN** each rendering matches its committed golden image

#### Scenario: A styling change alters a control
- **WHEN** a change alters a control's size, shape or colour
- **THEN** the golden test fails and names the specimen and theme that differ, until the goldens are regenerated and committed

#### Scenario: No state animation
- **WHEN** a styled button, icon button and menu item are each pressed and then hovered in a widget test
- **THEN** no splash is painted, and each one's pressed and hovered colours appear on the next frame

#### Scenario: Documented exceptions
- **WHEN** a text field gains focus or a chip is selected in a widget test
- **THEN** the field's border and the chip's fill reach their final Ember colours once Material's transition ends, and no splash is painted

### Requirement: Keyboard focus is always visible
In both themes, every styled control SHALL show its focus indicator in the theme's Focus colour while it has keyboard focus, and none without focus. Buttons, icon buttons and chips show a 2-pixel outline 2 pixels outside their shape; menu items show it just inside theirs. Text fields show a Focus-coloured border with the Ember Glow halo.

#### Scenario: Tab to each control
- **WHEN** a widget test moves keyboard focus to each styled control in turn, in the dark and the light theme
- **THEN** on the next frame, each button and icon button paints a 2-pixel Focus-coloured outline outside its shape and each menu item paints one just inside its shape; each chip paints the outside outline once Material's 75ms ring tween ends; and each text field paints a Focus-coloured border with the halo once Material's 167ms border transition ends

#### Scenario: Focus leaves a control
- **WHEN** keyboard focus moves from a control to the next one
- **THEN** the first control no longer paints its focus indicator

#### Scenario: A control without a focus indicator
- **WHEN** a styled control is focused and paints no Focus-coloured indicator
- **THEN** the focus test fails and names the control and the theme

### Requirement: Token colours meet WCAG contrast
In both themes, every text colour role (ink, ink secondary, ink tertiary, prose, accent text) SHALL reach 4.5:1 against every surface it may sit on (canvas, panel, raised, hover, press). Text on Ember, warning and error fills SHALL also reach 4.5:1, and the Focus colour SHALL reach 3:1 against every surface. Translucent colours are measured composited over canvas.

#### Scenario: Current tokens pass
- **WHEN** the contrast test runs over the token values
- **THEN** every listed pair in both themes meets its threshold, and the test exits 0

#### Scenario: A token edit lowers contrast
- **WHEN** a token change brings a listed pair below its threshold
- **THEN** the contrast test fails and names the theme, the two roles, the measured ratio and the required ratio

#### Scenario: Ember fills are exempt from the surface bar
- **WHEN** the contrast test measures the Ember fill against a surface and finds less than 3:1
- **THEN** the test does not fail, because the fill is identified by its label, whose 4.5:1 pair is checked
