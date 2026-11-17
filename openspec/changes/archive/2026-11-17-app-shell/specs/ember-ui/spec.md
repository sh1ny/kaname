## MODIFIED Requirements

### Requirement: Keyboard focus is always visible
In both themes, every styled control SHALL show its focus indicator in the theme's Focus colour while it has keyboard focus, and none without focus. Buttons, icon buttons, chips and segmented-control options show a 2-pixel outline 2 pixels outside their shape; menu items show it just inside theirs. Text fields show a Focus-coloured border with the Ember Glow halo.

#### Scenario: Tab to each control
- **WHEN** a widget test moves keyboard focus to each styled control in turn, in the dark and the light theme
- **THEN** on the next frame, each button, icon button and segmented-control option paints a 2-pixel Focus-coloured outline outside its shape and each menu item paints one just inside its shape; each chip paints the outside outline once Material's 75ms ring tween ends; and each text field paints a Focus-coloured border with the halo once Material's 167ms border transition ends

#### Scenario: Focus leaves a control
- **WHEN** keyboard focus moves from a control to the next one
- **THEN** the first control no longer paints its focus indicator

#### Scenario: A control without a focus indicator
- **WHEN** a styled control is focused and paints no Focus-coloured indicator
- **THEN** the focus test fails and names the control and the theme

#### Scenario: Segmented-control option beside the selected one
- **WHEN** a widget test moves keyboard focus to a segmented-control option whose right-hand neighbour is selected, in the dark and the light theme
- **THEN** on the next frame, the focused option paints the 2-pixel Focus-coloured outline outside its shape on every side, above its neighbours
