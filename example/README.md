# cloud_media example

Minimal demo app exercising `cloud_media`'s pick/edit/crop/background-removal/
upload flow, plus the upload progress overlay and per-item controls.

## Running

```bash
cd example
flutter pub get
flutter run
```

You'll need a Firebase project wired up (`flutterfire configure` from this
directory, or drop in your own `google-services.json` / `GoogleService-Info.plist`)
since this app calls `Firebase.initializeApp()` before anything else.

## Note on `pubspec.lock`

This directory has no `pubspec.lock` checked in yet. Unlike the parent
`cloud_media` package (a library, where committing a lockfile is
discouraged — see the root `.gitignore`'s comment), this example is an
*application*, for which Dart's own guidance is the opposite: commit the
lockfile for reproducible builds. It isn't included here only because
generating one requires actually running `flutter pub get` against a real
Flutter SDK, which wasn't available while putting this example together.
Running `flutter pub get` once will create it — commit the result.
