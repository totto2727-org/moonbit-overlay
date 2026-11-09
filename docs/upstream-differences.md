# Upstream differences

This reference is for maintainers of the `totto2727-org/moonbit-overlay` fork.
The upstream repository is [moonbit-community/moonbit-overlay](https://github.com/moonbit-community/moonbit-overlay).
The exact upstream base is [`a9116185a96c716ec1a480eea848830a3991edef`](https://github.com/moonbit-community/moonbit-overlay/commit/a9116185a96c716ec1a480eea848830a3991edef).
This commit is the common ancestor of the fork's `master` and the inspected upstream reference.
The retained areas below describe the fork relative to that base, not a synchronization with a newer upstream revision.

| Area | Purpose | Operational impact |
| --- | --- | --- |
| `.github/workflows/`, fork URLs in `flake.nix`, `moonbit-dev/nix/flake.nix`, and `README.md` | Publish fork artifacts and use the shared FlakeHub publication workflow. | Releases use the fork repository. Flake lock updates use pull requests instead of direct commits. Publication skips development shell preparation. |
| `lib/utils.nix`, `lib/moonbit-bin.nix`, `scripts/fetch_toolchains.sh`, and `versions/toolchains/` | Provide supported Linux ARM64 toolchains and updated binary release records. | Versions without an ARM64 archive are not exposed for that platform. Binary URLs select the release repository for the available archives. |
| `lib/toolchains.nix` | Keep Linux TinyCC runtime helpers consistent with the selected TinyCC binary. | Linux toolchains use the matching Nix runtime helpers. Darwin retains the bundled compiler. |
| `lib/moonPlatform/`, `flake.nix`, `flake.lock`, and `test/` | Accept current `moon.mod` files and check package builds with a pinned registry. | Package evaluation uses the standalone MoonBit converter and Import From Derivation. Tests cover the supported manifest format. |
| `.gitignore` | Exclude scratch files and worktrees nested under root `tmp/` from Git status. | Local verification artifacts do not prevent clean-checkout synchronization. The rule does not change package builds or published outputs. |

The source changes above affect Nix packaging, toolchain selection, and build checks.
The fork distributes compiler binaries and does not include modified MoonBit compiler or runtime source.
The `tmp/` exclusion changes local Git behavior only.
Update this record and its exact upstream base when synchronizing upstream or changing retained fork behavior.
