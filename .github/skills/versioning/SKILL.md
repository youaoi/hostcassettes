---
name: versioning
description: "Bump Host Cassettes app version (major, minor, patch) or build number. Use when: bumping version, releasing a new version, incrementing build number, updating version strings, preparing a release."
argument-hint: 'e.g. "bump patch", "bump minor", "set version 1.0.0", "bump build"'
---

# Host Cassettes Versioning

## Version Architecture

- **Single source of truth**: [Info.plist](../../../Info.plist)
  - `CFBundleShortVersionString` — marketing version (e.g. `0.8.9`)
  - `CFBundleVersion` — build number (e.g. `3`)
- All build scripts and CI read from Info.plist dynamically via `PlistBuddy`. No other files need manual version edits.
- [Launcher-Info.plist](../../../Launcher-Info.plist) has its own independent version (`1.0`) — only update if launcher code changes.

## Sparkle Auto-Update

Sparkle は `sparkle:version`（= `CFBundleVersion`）を比較してアップデート判定を行う。
**バージョンを上げる際は必ず `CFBundleVersion` も更新すること。** ビルド番号が同じだと、ユーザーにアップデートが配信されない。

### CFBundleVersion のルール

| バンプ種別            | CFBundleVersion の扱い                          |
| --------------------- | ----------------------------------------------- |
| major / minor / patch | **1 にリセット**（新バージョン最初のビルド）    |
| build only            | **+1 インクリメント**（同バージョンの再ビルド） |

## Procedure

### 1. Determine bump type

| Type           | When                               | Example           |
| -------------- | ---------------------------------- | ----------------- |
| **patch**      | Bug fixes, small changes           | `0.8.8` → `0.8.9` |
| **minor**      | New features, backward-compatible  | `0.8.9` → `0.9.0` |
| **major**      | Breaking changes, major milestones | `0.9.0` → `1.0.0` |
| **build only** | Same version, rebuild              | build `3` → `4`   |

### 2. Read current version

```sh
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist
```

### 3. Update Info.plist

**major / minor / patch の場合（両方を更新）:**

1. `CFBundleShortVersionString` — 新しいマーケティングバージョンに変更
2. `CFBundleVersion` — **1 にリセット**

**build only の場合（1つだけ更新）:**

1. `CFBundleVersion` のみ **+1 インクリメント**（`CFBundleShortVersionString` は変更しない）

### 4. Verify no hardcoded versions

These files reference version dynamically and should NOT need edits:

- `package-release.sh` — reads via PlistBuddy
- `.github/workflows/release.yml` — reads via PlistBuddy

### 5. Optionally update CHANGELOG

Add a new entry at the top of [CHANGELOG.txt](../../../CHANGELOG.txt) following the existing format:

```
                         X.Y.Z
----------------------------------------------------
- Description of changes
```
