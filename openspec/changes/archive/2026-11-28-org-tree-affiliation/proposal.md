# Organisation tree and character affiliation

## Why

M3 needs an install-declared organisation tree and current corporation and alliance IDs for every character the install knows. This change advances the agent-verified exit criterion for a scheduled, tokenless refresh through the shared ESI scheduler. The owner's live check stays at M3 close: `member-states` and `groups-and-capabilities` are needed to complete it.

## What Changes

- Let the operator declare a single corporation, a single alliance, or a coalition of alliances as the install's tree.
- Refresh known characters' corporation and alliance after startup and then hourly. Also attempt one lookup when a character first enters the registry through verified CCP sign-in or linking. Both triggers use the public `POST /characters/affiliation` route through the shared scheduler, without a token. Failed lookups wait for the next hourly run.
- Apply the existing shared outage pause and recovery probe to the affiliation POST only. Keep existing GET behavior and do not replay refused affiliation calls.
- Make the tree and the latest successful affiliation observations readable to server code for `member-states`. Do not add client delivery or UI.
- Do not change account membership, owner-hash handling, token holder assignments, member states, admin rules, groups, or capabilities. Do not import outside rosters.

## Capabilities

### New Capabilities

- `org-affiliation`: install tree declarations, scheduled public affiliation refresh, and the server-side read contract.

### Modified Capabilities

- `esi-request-scheduling`: apply existing downtime admission and recovery to scheduled affiliation POSTs without attaching GET cache metadata.

## Impact

Install configuration and deployment documentation, the server's recurring work and Postgres schema, and the generated ESI client's existing scheduler integration. This change uses the identity registry shipped by `member-accounts`. It does not depend on `character-transfer`: public affiliation belongs to the character and does not depend on its account, owner hash, or token holder.

## Decision Making

DECISION_MAKING: all
Source: setting

### S1. Upgrade without a declared tree

- Choice: Keep the server available, expose an explicit unconfigured tree internally, and refresh affiliation on schedule. The owner's words: 'Keep running, tree unconfigured, still refresh affiliation.'
- Rejected: Defer refresh until a tree is configured, or refuse startup on an existing install without a declaration.
- Reversal cost: Medium. An upgrade that required a declaration would need a deployment change before restart.
- Important: yes. This defines upgrade and startup behavior.
- Chosen by: user.

### S2. Which characters to refresh

- Choice: Refresh every character in the install's CCP-verified identity registry, including blocked, unlinked, and device-held characters. The owner's words: 'Every character the install knows, incl. blocked or unlinked.'
- Rejected: Refresh only currently linked characters.
- Reversal cost: Low for the query; any excluded characters would have to wait for a later refresh.
- Important: yes. This defines which characters have observations available for future server readers.
- Chosen by: user.

## Branch gate

OpenSpec resolved to this worktree. The owner-authorized manual gate kept the existing clean `feat/org-tree-affiliation` branch at `ad22241302ca8ddd2d6348b57d1a054663afe884`, the freshly fetched `origin/main` tip. Local `main` lagged, and neither ref held an archive for this change. The checksum-verified Specwright 0.39.1 binary and notices were installed only in this worktree. The binary reported interface 3 and confirmed the worktree was clean.
