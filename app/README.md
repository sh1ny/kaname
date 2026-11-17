# kaname_app

The Kaname Flutter app for web, Windows, Linux, macOS, Android and iOS: the
adaptive app shell with empty module slots and a Settings screen. See the
repository README for setup.

## Running against a server

The app reads the server's health endpoint and shows the answer in the status
bar and in Settings → Server.

- **Web through the self-host stack** (`mise run stack:up`): the app calls its
  own origin's `/api/`. Release web builds always do this and ignore any
  server address.
- **Debug web without the stack:** start the development server
  (`mise run server:dev`), then give the address at build time:

  ```sh
  mise exec -- flutter run -d chrome --dart-define=KANAME_SERVER_URL=http://127.0.0.1:8080/
  ```

- **Desktop and mobile:** pass the same define, for example
  `mise exec -- flutter run -d windows --dart-define=KANAME_SERVER_URL=http://127.0.0.1:8080/`.
  Without it the app makes no server call and shows "No server configured". An
  address that is not an absolute `http` or `https` URL shows that the
  configured address is invalid. On an Android emulator the host machine is
  `10.0.2.2`, not `127.0.0.1`.
