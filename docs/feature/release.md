# Building for an environment and signing a release

Round 22 (`AI/docs/plans/plano-producao.md`, decisions 240-248), phase P1.
There are two environments on one server, production and staging
(homologação, decision 242); the apps learn which one at **build time**.
Nothing here is a secret: both values below are public, and the signing
key never enters the repository.

## Build-time configuration

| Define | Used by | Default (development) |
|---|---|---|
| `API_URL` | panel (`apps/admin`) and app (`apps/mobile`) | `http://localhost:3002` |
| `GOOGLE_SERVER_CLIENT_ID` | app — the **Web-type** OAuth client id whose id becomes the Google ID token's `aud` (decision 152, `app-auth.md`); must match `GOOGLE_OAUTH_CLIENT_ID` on that environment's API | the development client |

```sh
# Panel, production (static files for the proxy to serve)
cd apps/admin
flutter build web --release --no-web-resources-cdn \
  --dart-define=API_URL=https://api.<domain>

# App, staging
cd apps/mobile
flutter build appbundle --release \
  --dart-define=API_URL=https://api-homolog.<domain> \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<staging web client id>
```

A build without the defines points at the local API — fine for
development, wrong for any server. The domain is still open (round 22,
item 4).

## Android release signing (decision 246)

The Play Store refuses an app signed with the debug key, which is what
release builds used until P1. Now:

- **Play App Signing** holds the final app key. We sign uploads with an
  **upload key** that lives outside the repository.
- `apps/mobile/android/key.properties` (gitignored, like every `*.jks` and
  `*.keystore`) points at it:

  ```properties
  storeFile=/absolute/path/to/upload-keystore.jks
  storePassword=...
  keyAlias=upload
  keyPassword=...
  ```

- Create the upload key once, keep it with the master keys' offline copy
  (decision 243):

  ```sh
  keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```

- **Fails closed.** `flutter build apk --release` / `appbundle --release`
  without `key.properties` stops with "Release signing needs
  android/key.properties…" — never an unsigned or debug-signed release.
  Debug and profile builds never need the key; use `--profile` to try a
  release-like build on a device without it.

Verified in P1 on the Gradle version the project uses (8.14) with
stand-in tasks: debug/profile run without the key, `assembleRelease` and
`bundleRelease` stop with the message, and both read `key.properties`
when it exists. The full Android build was not run in that environment
(no Android SDK there) — the first `flutter build appbundle --release` on
a machine with the SDK and the upload key confirms the rest (P4).

## iOS

Later (decision 246). Signing stays in Xcode with the team's certificates;
nothing in the repository changes for it.
