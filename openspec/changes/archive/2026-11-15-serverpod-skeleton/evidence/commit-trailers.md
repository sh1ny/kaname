# Commit trailers (task 8.3)

Every commit on the branch up to the PR head `cba260f` ends with the owner's
`Signed-off-by` followed by the single `KintsugiBot` `Co-authored-by`, after
any `Specwright-Task` trailers. The group 8 commit that adds this file
carries the same block and is checked by the `signoff` job on its own push.

```text
$ git log main..cba260f8fcf949840b4df1675f64ecdcfe8298f7 --format=%H%n%(trailers)
cba260f8fcf949840b4df1675f64ecdcfe8298f7
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

2517e2410e012b20895d913277facef5ff982e84
Specwright-Task: 7.1
Specwright-Task: 7.2
Specwright-Task: 7.3
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

918ac4b2a39df64c49455adb7e750730e5338e30
Specwright-Task: 6.1
Specwright-Task: 6.2
Specwright-Task: 6.3
Specwright-Task: 6.4
Specwright-Task: 6.5
Specwright-Task: 6.6
Specwright-Task: 6.7
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

a821ac6f886dc79d4a83ab03244c7a7c85d06174
Specwright-Task: 5.1
Specwright-Task: 5.2
Specwright-Task: 5.3
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

b408f79e22ce72c5419b76409ead83846c761ee7
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

b49de6550cf820bd6c6edad44b39a396bcca0986
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

3005672fb3c6e9281441f6a9739267064a0feb85
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

4574cd058476815609b4b077041352f99c178d1f
Specwright-Task: 4.1
Specwright-Task: 4.2
Specwright-Task: 4.3
Specwright-Task: 4.4
Specwright-Task: 4.5
Specwright-Task: 4.6
Specwright-Task: 4.7
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

0c4671210f8f33ab70be17b509456963afe6c606
Specwright-Task: 3.1
Specwright-Task: 3.2
Specwright-Task: 3.3
Specwright-Task: 3.4
Specwright-Task: 3.5
Specwright-Task: 3.6
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

782f6ab15bf8af44eb683b02c4bf583b86c94764
Specwright-Task: 2.1
Specwright-Task: 2.2
Specwright-Task: 2.3
Specwright-Task: 2.4
Specwright-Task: 2.5
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

0e4fc6c9d1d6232c2ad49fd262ed57f340b653f1
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

ae70576e802cc352a6bc757c6531d870cd54dddf
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

6a0e1d64c871fd779440b4b91d1172ed610e5895
Specwright-Task: 1.1
Specwright-Task: 1.2
Specwright-Task: 1.3
Specwright-Task: 1.4
Specwright-Task: 1.5
Specwright-Task: 1.6
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

934ed5f1acb7c5a8e4fa600087ad127fb093ad20
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

dfac7278ac1d00bd2418992fe49ed8f26578feb6
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

ae4905303e50b856f66c776cfac3edab7af3b501
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

8147ecb60894e7c1cddad4246257765706fe5d34
Signed-off-by: Nikolay Bochev <309868+sh1ny@users.noreply.github.com>
Co-authored-by: KintsugiBot <296966193+KintsugiBot@users.noreply.github.com>

```

## The `signoff` job on the PR run

From run https://github.com/sh1ny/kaname/actions/runs/43731560566 (job
`signoff`, `success`), read with
`gh api repos/sh1ny/kaname/actions/jobs/132864910814/logs` through the fenced
KintsugiBot credential; timestamps and ANSI colour codes removed with `sed`,
lines otherwise verbatim.

```text
##[group]Run mise run signoff -- --base "$BASE_SHA" --head "$HEAD_SHA" --pr-author "$PR_AUTHOR"
mise run signoff -- --base "$BASE_SHA" --head "$HEAD_SHA" --pr-author "$PR_AUTHOR"
shell: /usr/bin/bash -e {0}
env:
  MISE_LOG_LEVEL: info
  MISE_TRUSTED_CONFIG_PATHS: /home/runner/work/kaname/kaname
  MISE_YES: 1
  JAVA_HOME: /home/runner/.local/share/mise/installs/java/temurin-17.0.21+9
  SPECWRIGHT_HOME: /home/runner/work/kaname/kaname/.specwright-local
  BASE_SHA: 8c16f86979d04c5c1d269a16e924fef9b1cae57c
  HEAD_SHA: cba260f8fcf949840b4df1675f64ecdcfe8298f7
  PR_AUTHOR: KintsugiBot
##[endgroup]
[signoff] $ dart run kaname_tools signoff --base 8c16f86979d04c5c1d269a16e924fef9b1cae57c --head cba260f8fcf949840b4df1675f64ecdcfe8298f7 --pr-author KintsugiBot
17 commits checked: signed off
```
