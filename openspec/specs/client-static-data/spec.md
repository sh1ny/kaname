# client-static-data Specification

## Purpose
Defines how the app learns which static-data bundle is current, downloads and keeps it on each platform, and swaps it in while running, so static data is available offline.

## Requirements

### Requirement: The app follows the announced bundle while connected
With a server address, the app SHALL subscribe to the build-change stream when it starts. When the stream ends or fails it SHALL subscribe again after 5 seconds, doubling to at most 5 minutes, and at once when the user checks the server again. When the announced bundle is not the one it holds, it SHALL download that bundle once. Within one server epoch it SHALL ignore an announcement whose revision is not higher than the last one it took.

#### Scenario: Start with an old bundle
- **WHEN** the app starts holding build N's bundle and the stream announces build N+1
- **THEN** the app downloads build N+1's bundle once

#### Scenario: Same bundle announced
- **WHEN** the stream announces the bundle the app already holds
- **THEN** the app downloads nothing

#### Scenario: Stream drops
- **WHEN** the build-change stream fails twice in a row
- **THEN** the app subscribes again 5 seconds after the first failure and 10 seconds after the second

#### Scenario: No bundle announced
- **WHEN** the app holds build N's bundle and the stream announces that no bundle is available
- **THEN** the app keeps build N's bundle in use and downloads nothing

#### Scenario: Stale announcement
- **WHEN** the app took revision 5 of an epoch and an announcement with revision 4 of the same epoch arrives
- **THEN** the app ignores it

#### Scenario: Server has no bundle yet
- **WHEN** the app holds no bundle and the stream announces that no bundle is available
- **THEN** the app downloads nothing and its reason is "server has no bundle yet"

#### Scenario: No server configured
- **WHEN** a desktop or mobile build has no server address
- **THEN** the app subscribes to nothing, downloads nothing and keeps any bundle it holds

### Requirement: Failed downloads keep the old bundle and retry
A download that fails (a 503 included), or a bundle a reader refuses, SHALL leave the bundle in use unchanged. The app SHALL retry after 1 minute, doubling to at most 30 minutes, and at once only when the stream announces another bundle; a reconnect announcing the same bundle SHALL NOT bypass the wait.

#### Scenario: Network error
- **WHEN** downloading build N+1's bundle fails with a network error while build N's is in use
- **THEN** build N's bundle stays in use and the download is retried 1 minute later

#### Scenario: Same bundle from a restarted server
- **WHEN** build N+1's bundle is downloading or waiting out a backoff, and the server restarts and announces build N+1's bundle under a new epoch
- **THEN** the running transfer goes on, or the backoff wait is kept

#### Scenario: Reconnect during backoff
- **WHEN** a download failed 20 seconds ago and the stream reconnects announcing the same bundle
- **THEN** no download starts until the 1-minute wait has passed

#### Scenario: Hash mismatch
- **WHEN** the app holds and has saved build N's bundle, and the downloaded bytes of build N+1 do not match the announced SHA-256
- **THEN** the bytes are discarded, build N's bundle stays in use and kept, an offline restart loads build N's bundle, and a retry is scheduled

### Requirement: The app skips a bundle format it cannot read
When an announcement names a major format version the app does not support, the app SHALL download nothing, keep the bundle in use, show that an app update is needed, and try again only when the announcement changes.

#### Scenario: Older app, newer format
- **WHEN** an app that reads format 1 is announced a format 2 bundle
- **THEN** it downloads nothing, its search keeps the format 1 bundle it holds, and the reason "app update needed" is available

#### Scenario: Same announcement again
- **WHEN** the stream reconnects and announces the same format 2 bundle
- **THEN** the app downloads nothing

### Requirement: Native apps keep the bundle as a file
Desktop and mobile apps SHALL keep one copy of the bundle in use as a file in the app's support directory, replaced whole by each save (written to a temporary file, then renamed over it), and SHALL load it at the next start without a download. The download URL SHALL be resolved against the server address the app uses.

#### Scenario: Offline start
- **WHEN** a desktop app holding build N's bundle file starts with no network
- **THEN** build N's bundle is loaded from the file and search works

#### Scenario: Interrupted save
- **WHEN** the app stops while saving build N+1's bundle, before the rename, and starts again offline
- **THEN** it loads build N's bundle, and a temporary file older than one hour is removed

#### Scenario: Offline restart after a rollback
- **WHEN** the app swapped from build N+1 back to build N after a rollback, saved it, and restarts offline
- **THEN** it loads build N's bundle

#### Scenario: Download URL follows the server address
- **WHEN** a native app is configured with `https://kaname.example/base` and the web app is served from its own origin
- **THEN** the native app downloads build N's bundle from `https://kaname.example/base/static-data/bundle/N/<hash>` and the web app from `/api/static-data/bundle/N/<hash>` on its origin

#### Scenario: Unreadable file
- **WHEN** the kept bundle file is truncated or fails its hash check at start
- **THEN** the file is not used and not deleted, the app holds no bundle, and it downloads the announced one when connected, whose save replaces the file

### Requirement: The web app keeps the bundle in the browser cache
The web app SHALL keep one copy of the bundle in use as one Cache Storage entry under a fixed key that holds its build and hash, replaced whole by each save, and SHALL load it on reload without a download. A load that finds the entry unreadable SHALL NOT delete it; the next save replaces it.

#### Scenario: Reload
- **WHEN** the web app holding build N's bundle is reloaded and build N is still announced
- **THEN** it loads build N's bundle from Cache Storage and downloads nothing

#### Scenario: Two tabs save
- **WHEN** the entry holds build N's bundle, two tabs save build N+1's and build N+2's bundles at about the same time, and a third tab loads offline while they save
- **THEN** each load finds one whole bundle of build N, N+1 or N+2, never a mix or nothing, and after both saves the entry holds the bundle saved last

#### Scenario: Unreadable entry while another tab saves
- **WHEN** one tab finds the entry unreadable and, before it finishes rejecting it, another tab saves build N's bundle
- **THEN** the entry still holds build N's bundle, and a fresh offline load loads it

#### Scenario: Cache Storage unavailable
- **WHEN** the browser refuses Cache Storage (for example in a private window or outside a secure context)
- **THEN** the app keeps the bundle in memory only, search works, and the next load downloads it again

### Requirement: A new bundle is swapped in between searches
The app SHALL check and index a new bundle in the background and then swap it in in one step. A search started before the swap SHALL finish on the bundle it started with, and every search started after it SHALL use the new bundle. No user action SHALL be needed.

#### Scenario: Swap during typing
- **WHEN** a search on build N's bundle has returned its results and build N+1's bundle is then swapped in
- **THEN** those results still show build N's names and ids, and the next keystroke searches build N+1's bundle

#### Scenario: Indexing fails
- **WHEN** indexing build N+1's bundle fails
- **THEN** build N's bundle stays in use and the failure is retried as a failed download

### Requirement: Work for a replaced announcement is dropped
Work for an announcement that has been replaced SHALL neither swap in nor schedule a retry. The app SHALL swap a verified bundle in before saving it and SHALL save only the bundle in use; when a save completes after the bundle in use changed, the app SHALL save the bundle in use again, so the kept copy converges to it.

#### Scenario: Newer announcement while indexing
- **WHEN** build N+1's bundle is indexing and the stream announces build N+2
- **THEN** build N+1's bundle is never swapped in or saved, and build N+2's bundle is downloaded only after build N+1's indexing ends

#### Scenario: No bundle announced while indexing
- **WHEN** build N+1's bundle is indexing and the stream announces that no bundle is available
- **THEN** build N's bundle stays in use and build N+1's bundle is neither swapped in nor saved

#### Scenario: Announcement changes during a save
- **WHEN** build N+1's bundle is in use and being saved, and build N+2's bundle is swapped in before that save completes
- **THEN** once the save of build N+1 completes, the app saves build N+2's bundle, and a later restart loads build N+2's bundle

#### Scenario: No bundle announced during a save
- **WHEN** build N+1's bundle is in use and being saved, and the stream announces that no bundle is available
- **THEN** the save completes, build N+1's bundle stays in use, and a later restart loads build N+1's bundle

### Requirement: The kept bundle is loaded before announcements are acted on
At start the app SHALL finish loading its kept bundle before acting on an announcement; announcements that arrive meanwhile SHALL wait, and only the latest SHALL be taken.

#### Scenario: Announcement before the kept bundle is loaded
- **WHEN** the app starts holding build N's bundle, and the first announcement names build N before the kept bundle has loaded
- **THEN** the app uses build N's kept bundle and downloads nothing

#### Scenario: Newer announcement before the kept bundle is loaded
- **WHEN** the app starts holding build N's bundle, and the first announcement names build N+1 before the kept bundle has loaded
- **THEN** build N's bundle is used until build N+1's is downloaded once and swapped in, and build N's never replaces it

### Requirement: Bundle work runs one at a time
At most one download, check and index SHALL run at a time. An announcement of another bundle or of no bundle SHALL cancel a running download by aborting its transfer, and one of the same bundle SHALL leave it running. Other running work SHALL finish and be dropped, and an aborted transfer SHALL have ended, before work for the latest announcement starts; announcements replaced while waiting SHALL be skipped.

#### Scenario: Newer announcement while downloading
- **WHEN** build N+1's bundle is downloading and the stream announces build N+2
- **THEN** the build N+1 transfer is cancelled, build N+2's download starts after it ends, and no retry is ever scheduled for build N+1

#### Scenario: Newer announcement while a native TLS handshake stalls
- **WHEN** a native app's download waits on a TLS handshake that the server accepted over TCP and never answers, and the stream announces another bundle
- **THEN** the transfer ends at once and the next download starts; the stalled socket may stay open until the server closes it, because the platform offers no way to close it during the handshake

#### Scenario: Repeated announcements while indexing
- **WHEN** build N+1's bundle is indexing and the stream announces builds N+2, N+3 and N+4 before that indexing ends
- **THEN** no other download or index starts until it ends, and then only build N+4's bundle is downloaded and indexed

#### Scenario: Bundle withdrawn and announced again
- **WHEN** build N+1's bundle is downloading, the stream announces that no bundle is available, and then announces build N+1's bundle again
- **THEN** the first transfer is cancelled, a new download of build N+1's bundle starts after it ends, and the cancelled transfer never schedules a retry

#### Scenario: Bundle withdrawn and announced again while indexing
- **WHEN** build N+1's bundle is indexing, the stream announces that no bundle is available, and then announces build N+1's bundle again before that indexing ends
- **THEN** the first index result is never swapped in, and build N+1's bundle is downloaded and indexed again after it ends

### Requirement: Events from a replaced subscription are ignored
When the app subscribes again, it SHALL ignore every later event, error and ending of the subscription it replaced, whatever epoch that event names, and only the current subscription's reconnect timer SHALL act.

#### Scenario: Old subscription after a resubscribe
- **WHEN** the user's server check resubscribes, the new stream delivers epoch E2's announcement, and the old stream then delivers an epoch E1 announcement and ends
- **THEN** the app keeps E2's announcement as its target and schedules no reconnect for the old stream
