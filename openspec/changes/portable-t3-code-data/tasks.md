## 1. Implementation

- [x] 1.1 Verify T3 v0.1.6 active and legacy paths, Scoop hook order, and shared portable helper semantics.
- [x] 1.2 Add opt-in builder injection for pre-install and post-uninstall portable hooks.
- [x] 1.3 Implement T3-specific process checks, sequential verified migrations, retry recognition, validation hooks, and owned-link cleanup.
- [x] 1.4 Add the four default data mappings while preserving architecture URLs, hashes, and updater blocker.

## 2. Verification

- [x] 2.1 Run synthetic Pester cases for migration, partial progress/retry, conflicts, links/reparse points, hash failure, process gate, and uninstall retention.
- [x] 2.2 Run isolated Scoop post_install failure/residual/retry probe; build and validate version, both URLs, Release hash metadata, and generated manifest hooks.
- [x] 2.3 Gracefully close T3 under U6 authorization, migrate only the verified default paths, retain source backups, and read back junction/persist state.
- [x] 2.4 Independently review implementation and records, fix findings, and record final evidence.
