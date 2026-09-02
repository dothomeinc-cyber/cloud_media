# Changelog

All notable changes to CloudMedia will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0

### Fixed
- README audit against real current source turned up several stale
  spots: Installation still showed `cloud_media: ^1.0.0` (package is
  now `1.1.0`); Configuration reference was missing 3 real
  `CloudMediaConfig` fields (`customStorageBucket`,
  `enableVideoCompression`, `videoCompressionBitrate` — the latter two
  now noted as not-yet-implemented, matching their doc comments);
  Delete's `showDeleteDialog` comment repeated the oversimplified
  "true if deleted, false if cancelled" claim the code's own doc
  comment already corrected earlier this session (it rethrows on a
  genuine delete failure rather than folding it into `false`).
- Every code example in the "Testing" section (added last pass) was
  re-verified line-by-line against real current source (`UploadControl`'s
  exact 5 methods, `debugOverrideUploadControl`'s signature,
  `MockFirebaseAuth(signedIn: true, ...)` matching the real fixed test
  file) rather than assumed correct from having just written it.

### Added
- README "Cleanup" section documenting `CloudMedia.dispose()`
  (added this session, previously undocumented) and an "Upload
  control" feature bullet for pause/resume/cancel.

### Fixed
- **`sync_providers_override_test.dart` (added last pass) failed all 6
  tests with `Bad state: ... was disposed during loading state, yet no
  value could be emitted.`** Root cause, confirmed directly from
  Riverpod's own author: `container.read(provider.future)` alone
  doesn't establish a listener, so the auto-dispose provider could be
  torn down (nothing was watching it) while still waiting for
  `Stream.value`'s first emission — which is never synchronous
  (confirmed against `dart:async`'s own `SynchronousStreamController`
  docs: "you won't get any events until the code doing the listen has
  completed"), so removing the `await` entirely (as one proposed fix
  suggested) would only have made the tests read `AsyncLoading` instead
  of the intended value, not fixed anything. The actual fix: added a
  `settle()` helper that `container.listen(...)`s the provider first
  (keeping it alive) and awaits an explicit non-loading signal, rather
  than relying on `.future` alone.

### Added
- README "Testing" section documenting `debugOverrideUploadControl`
  with a complete, real `UploadControl` implementation (previously
  undocumented despite being real, working public API).

### Added
- `sync_providers.dart`: most of it was previously assumed entirely
  untestable without real Firebase — checked more carefully this pass.
  `syncStateProvider`, `isMediaSyncingProvider`,
  `connectivityStatusProvider`/`isConnectedProvider`,
  `pendingMediaCountProvider`, and `syncStatusTextProvider` all
  ultimately wrap a `StreamProvider` from `riverpod_offline_sync`,
  which Riverpod's own `overrideWith` mechanism can replace with a fake
  stream directly (`ProviderContainer(overrides: [...])`, no
  `ProviderScope`/widget needed) — confirmed against Riverpod's own
  testing docs. Added real coverage for all of these. Only
  `syncMetricsProvider` remains untested — it reads
  `offlineSyncLayerProvider` and calls `.metrics` on the concrete,
  non-fakeable `OfflineSyncLayer` directly, which genuinely needs a
  real instance.
- `CloudFile` — the one media-display widget with no Firebase/async
  dependency at all (a plain `StatelessWidget` over a `CloudMediaItem`
  and two callbacks). `CloudImage`/`CloudVideo`/`CloudAudio` were left
  out of this pass — they load a real network/local resource and
  genuinely need a real device or extensive platform-channel mocking
  to exercise meaningfully, unlike `CloudFile`.

### Fixed
- `watchUntil` used `Future.delayed` for its timeout, which (unlike
  `Timer`) has no `.cancel()` — so on early success the delayed
  callback kept running in the background for the full `timeout`
  duration regardless, harmlessly (an `isCompleted` check made it a
  no-op) but wastefully. Switched to a cancellable `Timer`, stopped the
  moment `watchUntil` succeeds.
- `watchMultiple`'s per-item `CloudMedia.watch(id).listen(...)` calls
  had no `onError` — an error on any single underlying watch (e.g. the
  same permission-denied-after-sign-out case already fixed on
  `CloudMediaProvider.watchMedia`) was silently dropped by Dart's
  default unhandled-stream-error behavior instead of ever reaching
  whoever was listening to the combined stream. Added `onError:
  controller.addError`.
- Added `originalError` to `CloudMediaOfflineQueueException` and
  `CloudMediaSyncException`, matching the pattern already used by
  `CloudMediaUploadFailedException` — previously only that one carried
  the underlying cause; the other two are declared, public, and
  recognized by `ErrorHandler.handle()`, so kept consistent even though
  neither is thrown anywhere internally yet (same forward-compatible
  posture as this session's other declared-but-not-yet-thrown-from
  exception types).

### Fixed
- **`CloudMediaWatcher.watchMultiple()` leaked one Firestore
  subscription per media id, forever, on every call** — no way to
  cancel them at all. Rewrote to track each call's subscriptions and
  cancel them via the broadcast controller's `onCancel` (when the last
  listener unsubscribes) and via `dispose()`. Also removed a `_subscriptions`
  field that was declared and iterated in `dispose()` but never
  actually populated anywhere — pure dead weight.
- **`CloudMediaProvider.watchMedia()`'s cached per-`mediaId` Firestore
  listener could die permanently and silently.** Confirmed against
  Firebase's own docs: a snapshot listener stops emitting entirely
  after an error (e.g. permission-denied — genuinely reachable here,
  since a sign-out mid-watch removes the security-rule access that was
  granting it) and never recovers on its own. Any future `watchMedia`
  call for that id previously kept returning the same dead stream
  forever. Fixed so an error now tears the cache entry down, letting
  the next call establish a fresh listener.
- **`CloudMedia.dispose()` didn't exist at all** — `CloudMediaProvider`
  had a `dispose()` method, but nothing on the public `CloudMedia` API
  ever called it, so a consuming app had no way to clean up (cancel
  watch subscriptions, close the local cache's Hive box) even if it
  wanted to. Added `CloudMedia.dispose()`; `CloudMediaProvider.dispose()`
  is now properly `async` and also disposes `CacheService` (previously
  skipped entirely).
- **`OfflineSyncService.watchUploadProgress()` leaked a
  `StreamController` if every listener unsubscribed before the upload
  reached a complete/failed state** (e.g. the widget watching it is
  disposed early). Fixed via the broadcast controller's `onCancel`;
  verified no double-remove/double-close race against the existing
  completion-based cleanup path.
- `_sanitizeFolder` (path-traversal handling already verified safe
  earlier) had no length cap on the sanitized result — added a 200-char
  cap, since Firestore/Storage both enforce their own real path-length
  limits server-side and a clear, early rejection beats an opaque
  failure downstream.
- The one remaining bare-`const` throw of
  `CloudMediaSelectionLimitExceededException` (the hard-limit case in
  `Validators.validateSelectionCount`) now builds its message from the
  real `FileConstants.hardMaxSelection` constant directly, like the
  throw right below it already did, instead of relying on the
  exception's own hardcoded-literal default.
- **`CloudMediaConfig.uploadTimeout` was fully modeled (constructor,
  `copyWith`, `toJson`) but never actually applied anywhere** — a
  configured timeout silently did nothing, and an upload could hang
  indefinitely. Added `OfflineSyncService.uploadTimeout` (set from
  config by `CloudMediaProvider.initialize()`) and wrapped the actual
  `StorageQueue.uploadFile()` call in `.timeout(...)`; a timeout now
  throws `CloudMediaUploadFailedException`, which the existing
  catch/rethrow correctly routes into the same failed-progress
  emission and offline-queue retry path as any other upload failure.
- `enableVideoCompression`/`videoCompressionBitrate` doc comments now
  say plainly that video compression isn't implemented yet
  (`CompressionService.compressVideo` is a documented pass-through
  regardless of these settings) rather than implying they do something.

### Added
- `test/api/cloud_media_watch_test.dart` — covers what's actually
  testable on `CloudMediaWatcher` without Firebase (every other method
  calls `CloudMedia.watch()` directly with no injection seam):
  `dispose()`'s own safety on an untouched or already-disposed instance.


### Changed
- Dependencies bumped: `riverpod_offline_sync: ^2.0.0`,
  `permission_handler_package: ^3.0.0`, `native_cutout: ^0.3.0`.
- **Switched `isGranted` back to `isSufficient` for permission-denial
  checks in `permission_service.dart` and `cloud_media_provider.dart`.**
  In v1.1.0, `isSufficient` wasn't available on the actually-installed
  `permission_handler_package`, confirmed by a real compiler error, and
  the code was reverted to `isGranted` accordingly. A fresh
  `flutter analyze` against the updated install came back clean, and a
  direct diff confirmed `isSufficient` is present in the current
  source. Limited/provisional access (e.g. iOS's "Select Photos..."
  partial library grant) now correctly counts as usable again, rather
  than forcing a Settings-redirect loop the user never asked for.
- **`sync_providers.dart` rewritten to build on `riverpod_offline_sync`'s
  own exported providers instead of reimplementing them.** The package
  ships and exports `syncStateProvider`, `syncProgressProvider`,
  `pendingItemsCountProvider`, `queueBreakdownProvider`,
  `isConnectedProvider`, `connectivityStatusProvider` (see its
  `lib/src/providers/*.dart`, all re-exported from its public barrel)
  — CloudMedia had built its own versions of all of these from scratch
  by calling `OfflineSyncLayer.instance` directly. Worse,
  `pendingMediaCountProvider` and `queueBreakdownProvider` were one-shot
  `FutureProvider`s that never updated after their first read; the
  package's real equivalents are properly derived from
  `QueueManager.queueStream` and update live on every queue mutation
  (enqueue, process, retry, dead-letter, clear). CloudMedia's existing
  provider names/types are kept for backward compatibility (now thin
  re-exports/adapters), but `pendingMediaCountProvider` changed from
  `FutureProvider<int>` to a plain `Provider<int>` (matching the
  package's own shape) and `pendingOperationsProvider`/
  `queueBreakdownProvider` from `FutureProvider` to `StreamProvider` —
  updated the two internal consumers (`cloud_media_upload_overlay.dart`,
  `sync_status_indicator.dart`) accordingly, removing now-unnecessary
  `AsyncValue`/`.when()` unwrapping.
- **That rewrite initially used `someStreamProvider.stream` to re-derive
  a raw `Stream` from the package's providers — a real compiler error
  showed `.stream` doesn't exist on the actually-installed
  `flutter_riverpod` (`^3.3.2-dev.2`).** Confirmed directly from
  Riverpod's own author: `.stream` was deprecated in 2.3 and removed in
  3.0, with `.whenData` on the watched `AsyncValue` as the documented
  replacement for transforming a stream provider's data while
  preserving loading/error state. `syncStateProvider`,
  `syncProgressProvider`, `pendingOperationsProvider`, and
  `queueBreakdownProvider` are now plain `Provider<AsyncValue<T>>`
  wrappers using `.whenData(...)` instead of `StreamProvider`s built on
  `.stream.map(...)`. `.value` access at every consumer site still
  works unchanged, since `AsyncValue.value` is the same accessor either
  way.
- **`file_picker`'s `pickFiles()` changed from returning
  `FilePickerResult?` to a non-nullable `List<PlatformFile>` directly
  (confirmed against the package's own changelog — `FilePickerResult`
  was removed entirely in v12), breaking `upload_service.dart`'s
  `result.files` / `result != null` calls for audio and PDF multi-file
  picking.** `pickFile()` (singular) was unaffected — it already
  returned a nullable `PlatformFile?`, unchanged. Fixed both
  `pickFiles()` call sites to use the returned list directly; an empty
  list on cancellation produces the same empty `pickedFiles` result the
  old `result != null` guard's false-branch did.

## [1.1.0]

Rebuild pass focused on making the Firebase/offline-sync integration
correct and complete, closing gaps between what the package claimed to
do and what it actually did, and replacing guessed dependency APIs
with verified ones once their real source became available.

### Fixed after a real `flutter analyze` / `flutter test` run
A real compiler run surfaced issues no amount of manual source review
could — these are the actual errors it reported, and the fixes:
- `flutter analyze` flagged `_storageQueue` as could-be-`final`
  (`prefer_final_fields`) — accurate, since switching the test seam
  from `debugOverrideStorageQueue` to `debugOverrideUploadControl`
  (which sets `_uploadControlOverride` instead) means `_storageQueue`
  itself is never reassigned anywhere anymore. Made `final`. **This is
  the last item — with it, the full suite is 196/196 passing, 0
  skipped, 0 analyzer issues.**
- `PermissionResult.isSufficient` doesn't exist on the installed
  `permission_handler_package: 2.0.2` (only `isGranted` and
  `isPermanentlyDenied` do) — reverted the two call sites
  (`PermissionService._throwIfDenied`,
  `CloudMediaProvider._ensureReadPermission`) to `isGranted`, with a
  comment explaining why in case a future package version adds it back.
- `offline_sync_service.dart` imported `firebase_storage` only for
  `FirebaseException`, which `cloud_firestore` already provides
  (`unnecessary_import`) — removed.
- `fake_cloud_firestore`, `firebase_auth_mocks`, and `hive` dev
  dependencies were missing/unresolvable — `fake_cloud_firestore`'s
  pin was simply wrong (`^3.1.0` doesn't exist in a form compatible
  with this package's `cloud_firestore`), and `fake_cloud_firestore`
  itself requires `cloud_firestore >=6.7.1` while this package pinned
  `^6.5.0` — bumped `cloud_firestore` to `^6.7.1` and corrected the dev
  dependency versions to `fake_cloud_firestore: ^4.2.0` and
  `firebase_auth_mocks: ^0.15.2`, both confirmed against each
  package's published pub.dev compatibility table.
- `testWidgets(..., skip: 'a string reason')` — `flutter_test`'s
  `testWidgets` takes `skip: bool?`, not a string (unlike plain
  `test()` from `package:test`, which does accept a string). Fixed
  both skip calls in `upload_progress_indicator_test.dart` to
  `skip: true` with the reason moved to a comment.
- **A real bug in `countOperationsByCategory`, caught by its own
  test**: `op['category'] as String?` throws for any non-null,
  non-String value instead of falling back to `'unknown'` as intended
  — the test that specifically exercised a non-string category value
  (an `int`) crashed instead of passing. Fixed to use `is String`
  instead of a direct cast.
- Added `uses-material-design: true` to `cloud_media`'s own
  `pubspec.yaml` — missing entirely (Flutter defaults to `false`),
  despite 16 files across `lib/` using `Icons.*` directly. This is
  what `riverpod_offline_sync`'s own `uses-material-design: true`
  warning was surfacing, but it was a real, independent gap in this
  package regardless of that dependency.
- **`FirebaseService.initialize()` eagerly constructed `FirebaseStorage.instance`
  even when only `firestore`/`auth` were injected for a test** — every
  Firestore-only test crashed with `[core/no-app] No Firebase App
  '[DEFAULT]' has been created`, since nothing in those tests ever
  provides a `storage:` fake (this package doesn't use
  `firebase_storage_mocks`). Found by a real `flutter test` run.
  `_storage` is now a lazy getter, only touched by `downloadMedia` (the
  one method that actually needs it) — `initialize()` and every
  Firestore/Auth-only method no longer require Storage at all.
- **`MockFirebaseAuth(mockUser: ...)` alone doesn't sign the mock user
  in** — `signedIn` defaults to `false` on the real constructor
  (confirmed via its published API docs after a real test run showed
  `currentUser` was `null` despite `mockUser` being passed).
  `test/services/firebase_service_test.dart`'s setup now passes
  `signedIn: true` alongside `mockUser:`, which every "authenticated
  user" test actually needs. The one test intentionally exercising the
  no-user case already worked correctly by luck (its own defensive
  sanity-check assertion, written before this was confirmed, is now
  verified true) — left unchanged.
- **`FirebaseService.listMedia()`'s soft-delete filter,
  `.where('deletedAt', isEqualTo: null)`, has never actually filtered
  anything — on real Firestore, not just in tests.** Confirmed against
  an official FlutterFire maintainer response: passing `null` to
  `isEqualTo` is documented as a no-op, equivalent to no filter at all,
  because `null` is that parameter's own default value. Every
  `listMedia()` call was silently returning soft-deleted items right
  alongside active ones. This was invisible against real Firestore
  (which just silently ignores the redundant filter) — the only reason
  it surfaced at all is that `fake_cloud_firestore`'s query engine
  correctly throws `Unsupported` on the same construct instead of
  quietly accepting it. Fixed to `isNull: true`, the parameter
  Firestore actually provides for this. Note for production: this
  `where(isNull) + orderBy(a different field)` combination needs a
  composite index on real Firestore, which the console will offer to
  create automatically the first time the query runs unindexed.
- **Attempted to make `upload_progress_indicator_test.dart`'s two
  pause/cancel tests real instead of skipped — after four rounds of
  chasing Firebase-mocking internals (`[core/no-app]` →
  `[firebase_storage/no-bucket]` → `[core/duplicate-app]` → back to
  `[firebase_storage/no-bucket]`), found the actually-correct fix: none
  of pause/resume/cancel/isUploading/isCancelled ever touch Firebase
  Storage at all (only `uploadFile`/`deleteFile` do) — the only problem
  was `StorageQueue`'s *constructor* eagerly evaluating
  `FirebaseStorage.instance` regardless of which method gets called.**
  Extracted a small `UploadControl` interface (pause/resume/cancel/
  isUploading/isCancelled only) that `OfflineSyncService` now depends
  on for those five operations, with `_RealUploadControl` wrapping the
  real `StorageQueue` by default and a new
  `OfflineSyncService.debugOverrideUploadControl()`
  (`@visibleForTesting`) letting tests swap in a plain in-memory fake
  instead — sidestepping the Firebase-mocking problem entirely rather
  than continuing to fight it. Uploads/deletes still always go through
  the real `StorageQueue` directly, unaffected. Both tests are real,
  passing tests again.

### Added
- `CloudMedia.watchUploadProgress()`, `pauseUpload()`, `resumeUpload()`,
  `cancelUpload()`, `isUploading()` — real per-file upload progress and
  control, backed by `riverpod_offline_sync`'s `StorageQueue` rather
  than a disconnected local `StreamController` that nothing fed.
- `MediaGrid.showUploadControls` / `MediaLibraryScreen.showUploadControls`
  — optional pause/resume/cancel buttons on in-progress grid tiles.
- `LoadingDialog.showHandle()` — closes the specific dialog instance it
  returned a handle for, regardless of what else is on the navigator
  stack, instead of `hide()`'s previous "pop whatever's on top" approach.
- `MediaPickerScreen.onError` — reports the exception that caused the
  screen to close instead of always popping silently.
- `FirebaseService` now accepts injected `FirebaseFirestore`,
  `FirebaseStorage`, and `FirebaseAuth` instances (all optional; real
  app behavior unchanged) so it can be unit-tested against
  `fake_cloud_firestore` / `firebase_auth_mocks` instead of only being
  reachable via integration tests against a live project.
- Test suite: model round-trip tests (including a real Firestore
  round-trip via `fake_cloud_firestore`), pure-logic unit tests for
  validators/formatters/error handling/permission mapping, and a
  widget test for upload-progress controls.

### Fixed
- **`CloudMedia.pick()` never requested any permission at all.** All
  prior permission handling only covered the separate
  `MediaPickerScreen` / `PermissionAwareMediaPicker` widgets — the
  primary documented API path relied entirely on `image_picker` /
  `file_picker`'s own OS-level prompts, with no explanation dialog and
  no way to distinguish "permission denied" from "user picked nothing."
  `CloudMedia.pick()` now requests the correct permission first and
  throws `CloudMediaPermissionDeniedException` /
  `CloudMediaPermissionPermanentlyDeniedException` on denial.
- **Wrong Android permission requested for gallery picks.** Image/video
  picks were requesting `PermissionType.storage` (the legacy
  `READ_EXTERNAL_STORAGE`), which is a no-op on Android 13+ — the OS
  enforces `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO`
  instead. Now maps each media type to its correct granular permission.
- **Wrong permission type requested for audio file picks and gallery
  picks in `MediaPickerScreen`.** These were requesting camera or
  microphone permission for flows that only ever pick existing files —
  never touching the camera or microphone at all.
- **`CloudMediaConfig.enableLogging` was fully modeled but never
  applied** — `CloudLogger.isEnabled` defaulted to always-on regardless
  of what a consuming app configured. Now wired through at
  initialization.
- **Sync/connectivity status providers were permanently stuck** at
  their initial values (`idle`, `0.0`, always-connected) — nothing ever
  called `.set()` on the `Notifier`s backing them, so
  `CloudMediaUploadOverlay` could never reflect real sync progress or a
  dropped connection. Now stream from `OfflineSyncLayer`'s real
  `syncState` / `syncProgress` / `connectivityMonitor`.
- **`ErrorHandler.handle()` didn't recognize any of the package's own
  typed exceptions**, so `getUserFriendlyMessage()` returned an ugly
  `"CloudMediaXyzException: ..."` string via `toString()` instead of
  the exception's own clean message. `isPermissionError()` also missed
  the permanently-denied case entirely.
- `ErrorMessages` and `UIConstants` were fully dead code, and
  `ErrorMessages`'s text had already drifted from the hardcoded
  defaults actually used in `error_handler.dart` for the same concepts.
  Exception defaults now reference `ErrorMessages` directly.
- `FileUtils.isImage/isVideo/isAudio` hardcoded a third, independent
  copy of the accepted-extension lists (separate from `FileConstants`
  and `CloudMediaType.acceptedExtensions`) — now defers to
  `FileConstants`.
- `DateFormatter.formatDuration` silently wrapped for any duration an
  hour or longer (`05:30` shown for what was actually 1h05m30s) —
  now includes the hour component when present.
- `CloudImage`'s `enableZoom` path (used by the full-screen review and
  viewer flows) still preferred the low-resolution thumbnail over the
  full-resolution URL, defeating the point of zooming.
- `CloudVideo` / `CloudAudio` had no `didUpdateWidget` handling, so a
  `PageView` or grid reusing the `State` object for a different media
  item (no distinguishing `Key` at any call site) could keep playing
  the previous item's video/audio. Both now re-initialize correctly,
  with a race guard against a stale init call resolving after a newer
  one superseded it.
- `CloudAudio` used `setSourceUrl()` even for local file paths;
  `audioplayers` documents `setSourceDeviceFile()` for that case.
- `CloudHlsPlayerScreen` / `CloudHlsPlayer` skipped loading the stream
  entirely when `autoPlay: false`, not just auto-starting playback,
  leaving a permanently black, uncontrollable player.
- Uploads went through a bare `ref.putFile()` inside a fire-and-forget
  operation-queue handler with no real progress reporting and no
  pause/resume/cancel. Now routed through `StorageQueue`, with the
  operation queue still providing offline durability while a file
  upload is waiting to start.
- **`CloudMediaWatcher.watchUploadProgress()` was completely dead.** It
  reads `metadata['progress']` from the Firestore-watched document, but
  nothing anywhere in the codebase ever wrote that field — it always
  reported `0.0` while uploading and jumped straight to `1.0` on
  completion, never any real intermediate value. This is a second,
  independent progress path from `OfflineSyncService.watchUploadProgress`
  (in-memory stream, added this pass) — now the upload handler also
  writes throttled progress fractions (~5% increments, to avoid
  excessive Firestore write costs) to `metadata.progress` so this path
  works too.
- `OfflineSyncService.forceSync()` reflection-guessed between
  `.forceSync()` and `.sync()` via `dynamic` / `NoSuchMethodError`
  catching; now calls the real `.sync()` method directly.
- Removed three declared dependencies that were never actually
  imported anywhere in the package (`image_background_remover`,
  `image_cropper`, `connectivity_plus`) — the features they were meant
  for are implemented via `native_cutout`, `flutter_img_editor`, and
  `riverpod_offline_sync`'s own connectivity monitor respectively.
- Removed a `test/` directory that contained an unrelated project's
  auth test scaffolding (wrong package, wouldn't compile here) and
  stray literal `{a,b,c}`-named directories left over from a shell
  command that ran without brace expansion.
- Example app called `OfflineSyncLayer.instance.initialize()` directly
  in addition to `CloudMedia.initialize()` (which already does this
  internally) — the example's own `SyncConfig` was silently ignored by
  whichever call won the race. `example/pubspec.yaml` also declared
  `permission_handler_package` commented-out while still importing and
  calling it, and pinned a different `riverpod_offline_sync` version
  than the main package.
- `README.md` documented `PermissionService.requestMediaPermissions(context, ref)`
  and `watcher.watchUntil(id, status: ..., timeout: ...)` — both stale
  after signature changes made earlier this pass (the former now
  requires a `CloudMediaType` first argument; the latter's target
  status is a required positional parameter, not named `status:`).
  Neither example would have compiled as written.

### Changed
- `CloudMediaProvider.pickMedia`'s `enableEditing` default corrected
  from `true` to `false`, matching `CloudMedia.pick()`'s own default
  (the provider's old default was unreachable dead code in practice,
  but a real trap for anyone calling the provider directly).
- `OfflineSyncService.createMediaMetadata`'s `metadata` parameter
  renamed to `documentData` — it always held the entire Firestore
  document to write (typically `CloudMediaItem.toFirestore()`'s full
  map), never just the item's own `metadata` sub-map, and the old name
  was genuinely confusing on that point.
- **`CloudMedia.initialize()` had no re-entrancy guard** — every other
  `initialize()` in the codebase (`CloudMediaProvider`,
  `OfflineSyncService`, `PermissionHandler`) already no-ops on a second
  call; this one would silently construct and swap in a brand new
  `CloudMediaProvider`, leaving anything holding a reference built
  against the old config (e.g. an already-constructed `UploadNotifier`,
  which reads `CloudMedia.config` once at construction) using stale
  state. Now guarded the same way as the others.
- `CloudMedia.showDeleteDialog`'s doc comment claimed it "returns true
  if deleted, false if cancelled" with no mention that a confirmed-but-
  failed delete (network error, permission issue) rethrows rather than
  returning `false` — the example app's own usage had no error handling
  around this call as a result. Doc comment now states the real
  contract clearly; example app now catches and surfaces the error.
- **`CompressionService.compressImage` and
  `BackgroundRemovalService.removeBackground` both silently returned
  the original path unchanged when given a nonexistent file** —
  indistinguishable from their own "processing failed, fall back to the
  original" cases, except there was no valid original to fall back to.
  Both now throw (`CloudMediaCompressionException` and the new
  `CloudMediaInvalidInputException` respectively) instead of silently
  handing back an invalid path that would only fail much later, more
  confusingly, at the Firebase upload stage.
- `_mimeTypeForPath` (used when building the Firestore `mimeType` field
  after picking) didn't handle `.m4a`, a real accepted audio extension
  — masked in practice by a correct fallback to the original picked
  file's mime type (audio is never transcoded in this pipeline), but a
  fragile invariant to leave undocumented. Added directly for
  completeness.
- **Breaking: `mediaListProvider`'s `String userId` family parameter was
  silently ignored** — `CloudMediaProvider.listMedia()` has no `userId`
  parameter at all (every Firestore path is scoped to whichever user is
  currently signed in via `FirebaseAuth.instance.currentUser`, and
  nothing anywhere in this package supports querying another user's
  media). The provider looked like it selected which user's media to
  list but always returned the current user's regardless of what was
  passed — actively misleading for exactly the multi-user use case that
  parameter implied was supported. Changed to a plain
  `FutureProvider<List<CloudMediaItem>>` with no parameter. Unused
  anywhere in this codebase, but if your app called
  `ref.watch(mediaListProvider(someUserId))`, drop the argument.

### Added (continued)
- Test coverage extended to every genuinely unit-testable
  service/util/model that previously had none: `PlatformUtils`,
  `CloudLogger`, `PickedFile`/`UploadProgressData`,
  `ThumbnailService.generateThumbnailBytes` (using real in-memory PNG
  bytes via the `image` package), `CompressionService` and
  `BackgroundRemovalService`'s precondition checks, and `CacheService`
  end-to-end (set/get/remove/clearAll/LRU eviction) against a real Hive
  box backed by a real temp directory — made possible by adding the
  same constructor-injection seam to `CacheService` that
  `FirebaseService` already had, so it no longer requires
  `hive_flutter`'s platform-channel-dependent `initFlutter()` to test.
- Extracted `mapSyncStateType` and `countOperationsByCategory` out of
  `sync_providers.dart`'s `StreamProvider`/`FutureProvider` closures
  into standalone pure functions (same reasoning as the earlier
  `shouldPersistProgress` extraction in `offline_sync_service.dart`) —
  the mapping/aggregation logic is now independently unit-tested
  without needing a real offline sync queue in flight.

### Removed
- `fix.sh` — this repair script targeted an architecture that no
  longer matches the current codebase (a separate
  `storage_queue_service.dart` that doesn't exist post-rebuild, and
  stripped-down/pre-fix versions of `sync_providers.dart`,
  `upload_service.dart`, `permission_service.dart`,
  `offline_sync_service.dart`, and `media_library_screen.dart`).
  Running it would have silently reverted every fix in this release and
  deleted the example app. Kept as changelog history only — there is no
  scenario where running it against the current tree helps.

## [1.0.3]
- folder updated
- All packages up to date
- All the permission handled safely
- removed dependency error

## [1.0.2]

- All packages up to date
- All the permission handled safely
- removed dependency error


## [1.0.0]

- All packages up to date
- All the permission handled safely

## [0.0.9] - 2026-28-12

- All packages up to date


## [0.0.8] - 2026-06-12~

- All packages up to date

## [0.0.6] - 2026-06-12

- All packages up to date

---

## [0.0.2] - 2026-06-05

### Added
- Web platform support with conditional imports and IndexedDB caching
- Video thumbnails via `flutter_video_thumbnail_plus`
- ML Kit background removal (Selfie Segmenter) with fallback chain
- Full `image_cropper` integration for cropping dialog
- Complete editor screen with crop, rotate, flip, brightness, contrast, saturation, blur
- Video compression with H.264 encoding, resolution scaling, and progress streaming
- HEIC/HEIF to JPEG conversion, GIF support, MKV video, FLAC audio
- Background sync with WorkManager (Android) and BGTaskScheduler (iOS)
- New APIs: `compressVideo()`, `removeBackground()`, `edit()`, `deleteMany()`, `restoreMany()`, `pauseSync()`, `resumeSync()`, `getCacheSize()`, `updateMetadata()`

### Changed
- `CloudMediaWatcher.watchUntil()` now completes correctly on target status
- `MediaGrid` performance improved with builder pattern and keep-alive
- All Riverpod `StateProvider` migrated to `NotifierProvider` for v3.x compatibility

### Fixed
- `isMediaSyncingProvider` boolean access (was throwing on `.when()` call)
- `syncStatusTextProvider` uses `.when()` instead of `.valueOrNull`
- `FilePicker` static method usage for v12.x API
- `share_plus` API updated to v13 (`ShareParams`)
- Memory leak in `CloudMediaWatcher` subscriptions

### Deprecated
- `CloudMediaListExtension` methods — use `CloudMedia.list()` directly with options

### Removed
- `LocalBackgroundRemovalProvider` stub (replaced by ML Kit, kept as fallback)

### Security
- Download URLs expire after 7 days via Firebase Storage rules
- MIME type sniffing prevents extension spoofing

---

## [0.0.1] - 2026-06-05

### Added
- Core API: `pick()`, `list()`, `watch()`, `delete()`, `restore()`, `download()`, `share()`, `get()`, `sync()`, `initialize()`
- Media support: images (JPG, PNG, WebP), videos (MP4, MOV), audio (MP3, AAC, M4A), PDFs
- Automatic image compression to WebP @ 85% quality
- On-device thumbnails (200×200 WebP)
- Offline sync with `riverpod_offline_sync` queue
- LRU disk cache (500MB, 30-day TTL)
- UI widgets: `CloudImage`, `CloudVideo`, `CloudAudio`, `CloudFile`, `MediaGrid`, `UploadProgress`, `SyncStatusIndicator`
- Screens: `MediaPickerScreen`, `ReviewScreen`, `MediaLibraryScreen`, `BackgroundRemovalScreen`
- Services: Firebase, upload, cache, compression, thumbnail, offline sync, permissions
- 13 typed exceptions for error handling
- `CloudMediaConfig` with 14 configurable options

### Dependencies
- Firebase (Core, Auth, Storage, Firestore): ^4.10.0–^6.5.0
- Image Picker, File Picker, Video Player, Audio Players
- Riverpod 3.x with offline sync
- Hive, Path Provider, Share Plus, Connectivity Plus

### Supported Platforms
- Android, iOS, macOS, Windows, Linux (fully supported)
- Web (partial — requires platform abstraction)

### Known Limitations
- Video compression pass-through only (resolved in 0.0.2)
- Video thumbnails not implemented (resolved in 0.0.2)
- Cropping dialog stub (resolved in 0.0.2)
- Background removal stub (resolved in 0.0.2)
- Editor screen stub (resolved in 0.0.2)
- Web platform requires conditional imports (resolved in 0.0.2)
