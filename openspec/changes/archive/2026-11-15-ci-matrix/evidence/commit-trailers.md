# Evidence: commit trailers on this branch (task 6.3)

Captured on 2026-11-15 with `git log main..45fae585f0f173e164374ad0df91845bb14b8a62 --format=%H%n%(trailers)`. That is every commit on `chore/ci-matrix` up to the head CI checked. On every commit the owner's `Signed-off-by` is the final trailer block's second-to-last line, and the single `Co-authored-by: KintsugiBot` follows it last.

```text
45fae585f0f173e164374ad0df91845bb14b8a62
Feedback-Round: 1
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

21a6ce596e93d1a384fb71c6ca5d99719dbb4a8d
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

2a9e3234b5c07d82ff83ddfa9e7decd816cbcaff
Feedback-Round: 1
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

9c4f6d9e9df1e39ea69d082243fa62c337590ee7
Specwright-Task: 5.1
Specwright-Task: 5.2
Specwright-Task: 5.3
Specwright-Task: 5.4
Specwright-Task: 5.5
Specwright-Task: 5.6
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

4ec75acf33bd363d8aae3171ccfd5357e84d327a
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

8ce28bc503ec334e8198b726c79e187e8b7fff78
Specwright-Task: 4.1
Specwright-Task: 4.2
Specwright-Task: 4.3
Specwright-Task: 4.4
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

7d049e287e4e1099ce0d6e969c072c42b70c123f
Specwright-Task: 3.1
Specwright-Task: 3.2
Specwright-Task: 3.3
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

795b458ec3e345f6723c1cab1ee6d0a6b0267698
Specwright-Task: 2.1
Specwright-Task: 2.2
Specwright-Task: 2.3
Specwright-Task: 2.4
Specwright-Task: 2.5
Specwright-Task: 2.6
Specwright-Task: 2.8
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

2791929e0e5c899176511b1a6b2909a8028c3040
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

9a4f7d8aa8c87afba8e9d15de7f572a00ee7e243
Specwright-Task: 1.1
Specwright-Task: 1.2
Specwright-Task: 1.3
Specwright-Task: 1.4
Specwright-Task: 1.5
Specwright-Task: 1.6
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

756c86c0bd3d24645433c7a4798d3343c597c77a
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

fdb22e8446615ca614b15597b1e02d478591e93c
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

```

## The `signoff` job

From the `signoff` job of run https://github.com/sh1ny/kaname/actions/runs/43659239596 (head `45fae58`):

```text
$ dart run kaname_tools signoff --base cd9748166cffd688ccb616d5a5ce60e81604670e --head 45fae585f0f173e164374ad0df91845bb14b8a62 --pr-author KintsugiBot
12 commits checked: signed off
```

The job concluded `success`.
