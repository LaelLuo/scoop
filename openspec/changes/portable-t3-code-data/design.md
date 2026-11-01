## Context

T3 Code v0.1.6 stores its main home in `%USERPROFILE%/.t3`, with project/thread/settings state under `userdata`. The current Electron profile is `%APPDATA%/t3code-v2`. Windows legacy Local State fallback order is `%APPDATA%/T3 Code (Alpha)`, then `%APPDATA%/t3code`. The shared Scoop portable helper may ignore copy errors and still delete the source, so T3 needs a dedicated implementation.

## Goals / Non-Goals

- Goals: persist the four default directories; migrate existing data with byte-tree verification and retained source backups; keep completed mappings valid if a later path fails; make retry idempotent.
- Non-Goals: migrate custom paths or user workspaces; install, update, or run T3 Code.

## Decisions

- Keep `portableProfile` as the manifest declaration and use a T3-specific inline module. Add opt-in builder options `preInstall` and `postUninstall`; inject pre-install module calls before each architecture's existing `pre_install` steps.
- `PreInstall` checks known T3 main/resource-monitor processes before touching paths, then handles mappings sequentially. It copies to a deterministic staging path under persist, compares relative paths, entry types, and file SHA-256, and confirms the source did not change. Only after verification does it preserve the source as `.scoop-t3-code-backup`, activate the persist target, and create a junction.
- Each mapping recognizes source/target/backup/stage state. A completed source junction is reused by link ownership and target type; its retained backup is a historical snapshot and is not compared with the live target after T3 starts writing. A source/target tree comparison is only used to distinguish an interrupted first copy from a genuine conflict while the source remains a normal directory. There is no cross-path rollback: completed mappings and their backups remain valid when a later path fails, and retry processes them idempotently.
- `post_install` and `pre_uninstall` only verify mappings and process state. `post_uninstall` removes only links whose exact target matches this manifest; persist and source backups remain.
- Real user paths are processed only after graceful T3 exit under U6 authorization. No T3 install/update/launch is part of the migration.

## Scoop Failure Evidence

An isolated Scoop core was given a synthetic local ZIP manifest whose `post_install` throws. Scoop had already created the `current` junction, shim, and persist/userdata directory, but had not saved `scoop-manifest.json` or `scoop-install.json`. A retry recognized a previous failed installation, reported that removal of the old version directory may be in use, then reinstalled the same version successfully and saved metadata. T3 migration therefore runs before current/shim activation; the T3 `post_install` is read-only.

## Risks / Trade-offs

- A complete source backup remains beside each migrated profile so the original bytes are recoverable.
- SHA256 verification adds first-install time and covers directory entries, entry types, and file contents, not ACLs, timestamps, or alternate data streams.
- Filesystem checks and changes are not atomic against another process launched in the narrow interval; process checks and before/after snapshots reduce but do not eliminate that race.

## Verification

- Pester synthetic tests cover fresh/empty mappings, migration, post-migration persist writes across validation/uninstall/reinstall, a later-path failure with earlier mappings preserved, retry, conflicting targets, foreign/damaged junctions, nested reparse points, transient hash failure, process gates, and uninstall data retention.
- A synthetic Scoop core verifies post-install failure residual state and retry behavior.
- Build and validate source/generated manifests, check stable version and both URLs, compare Release API SHA256 metadata with WinGet, and verify real migrated source links, persist trees, backups, legacy paths, and the unchanged updater blocker.
