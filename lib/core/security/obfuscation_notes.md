# Release build hardening (OWASP Mobile M7/M8)

Dart code is trivial to decompile from an unobfuscated release build's
snapshot. Every release/prod build **must** be built with symbol
obfuscation and a saved debug-symbol map:

```bash
flutter build apk --obfuscate --split-debug-info=build/debug-info/android

flutter build ipa --obfuscate --split-debug-info=build/debug-info/ios
```

(No `-t`/`--flavor` needed — the app ships a single entrypoint, `lib/main.dart`,
which is Flutter's default build target, and there are no native Android/iOS
build flavors declared.)

- `--obfuscate` renames Dart symbols in the compiled snapshot.
- `--split-debug-info=<dir>` writes the symbol map needed to de-obfuscate a
  production stack trace; **archive this directory per release** (it's what
  turns an obfuscated crash report back into readable Dart) but never ship
  it inside the app bundle itself.
- CI should refuse to publish a release artifact that wasn't built with
  both flags — a plain `flutter build` binary defeats the point of
  `core/security/` (root/jailbreak checks, pinning logic, etc. are all
  readable strings in an unobfuscated binary otherwise).

This is a build-pipeline concern, not something enforceable from within
`lib/`, hence the note-only file — wire the flags above into whatever CI
job produces the `prod` flavor's release artifact.
