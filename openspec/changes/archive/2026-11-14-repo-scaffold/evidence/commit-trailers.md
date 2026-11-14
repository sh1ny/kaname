# Evidence: Signed-off-by before Co-authored-by on every commit (task 6.5)

Date: 2026-11-14, branch `feat/repo-scaffold`. Command: `git log --reverse --format='%H%n%(trailers)' main..HEAD`, recorded before group 6's own commit and after the two design amendments (a commit cannot record itself; the orchestrator checks that commit the same way after making it and reports the result).

```text
aac41f16eb64fdba759a1edc45dbff9df97628b2
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

cb5c49dd63146f27f24db3b47d40c02dfe0f9134
Specwright-Task: 1.1
Specwright-Task: 1.2
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

44437595fd9b20c35194765d870adbedbdeeb4b5
Specwright-Task: 2.1
Specwright-Task: 2.2
Specwright-Task: 2.3
Specwright-Task: 2.4
Specwright-Task: 2.5
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

934e78bf90225b9570e91ff8c8ae8e0c5c5cc087
Specwright-Task: 3.1
Specwright-Task: 3.2
Specwright-Task: 3.3
Specwright-Task: 3.4
Specwright-Task: 3.5
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

7762c44f5aca8203fcb476d68c069d1e7b874799
Specwright-Task: 4.1
Specwright-Task: 4.2
Specwright-Task: 4.3
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

ddb61e8e57149909227e9628a232529392c97933
Specwright-Task: 5.1
Specwright-Task: 5.2
Specwright-Task: 5.3
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

06fe53491dbf27b0ac07692c95db3de4973ea7c8
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

11c37d628ca7339819b1bae0b98e3e38df187af9
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>
```

Position check per commit (line numbers within the trailer block):

| Commit | Subject | `Signed-off-by` line | `Co-authored-by` line | `Co-authored-by` count | Last trailer |
|---|---|---|---|---|---|
| aac41f1 | add planning artifacts | 1 | 2 | 1 | Co-authored-by |
| cb5c49d | group 1 Preconditions and commit rules | 3 | 4 | 1 | Co-authored-by |
| 4443759 | group 2 Workspace, app and core package | 6 | 7 | 1 | Co-authored-by |
| 934e78b | group 3 kaname_tools: workspace and purity checks | 6 | 7 | 1 | Co-authored-by |
| 7762c44 | group 4 THIRD_PARTY_NOTICES | 4 | 5 | 1 | Co-authored-by |
| ddb61e8 | group 5 Contribution policy documents | 4 | 5 | 1 | Co-authored-by |
| 06fe534 | amend design | 1 | 2 | 1 | Co-authored-by |
| 11c37d6 | amend design | 1 | 2 | 1 | Co-authored-by |

In every commit the owner's `Signed-off-by` comes after any `Specwright-Task` trailers and directly before the single KintsugiBot `Co-authored-by` trailer, which ends the block.
