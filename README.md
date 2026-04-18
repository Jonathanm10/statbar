# MenuBarStats

A native macOS menu-bar utility that shows CPU, memory, and disk usage at a glance, with a popover that lists the top processes consuming each resource.

Built in Swift / AppKit + SwiftUI. Sandboxed, code-sign-free for local builds, and designed to keep its own overhead small.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later (Swift 5.10)

## Build from source

Clone the repo and open the Xcode project:

```bash
git clone https://github.com/<your-org>/startbar.git
cd startbar
open MenuBarStats.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project MenuBarStats.xcodeproj \
  -scheme MenuBarStats \
  -destination 'platform=macOS,name=My Mac' \
  build
```

Run the full test suite (host + package):

```bash
xcodebuild -project MenuBarStats.xcodeproj \
  -scheme MenuBarStats \
  -destination 'platform=macOS,name=My Mac' \
  test
```

Package-only loop (faster, no app host):

```bash
swift test --package-path MenuBarStatsPackage
```

## Architecture

The app is a thin AppKit host wrapped around a local Swift package.

- `MenuBarStats/App/` — AppKit lifecycle, status-item + popover ownership, preferences, launch-at-login, settings store, helper XPC client.
- `MenuBarStats/Helper/` — tiny helper daemon (built as a post-build step) for privileged sampling.
- `MenuBarStatsPackage/Sources/MenuBarStatsFeature/` — canonical feature surface: refresh coordination, host stats reading, disk usage, process list, view models, SwiftUI views.
- `MenuBarStatsPackage/Tests/MenuBarStatsFeatureTests/` — package-level unit tests.
- `MenuBarStatsTests/` — host-only tests not already covered by the package.

Design rules worth keeping in mind when contributing:

- The AppKit lifecycle is the single owner of app/status-item behavior.
- The package is the single owner of sampling cadence and data publication.
- Host-only concerns (settings, preferences, launch-at-login) stay in `MenuBarStats/App/`.

## Performance

Resource minimization is profiling-first. Signposts are emitted for summary refresh, disk refresh, process-list work, and status-item rendering. The current profiling workflow lives in [`docs/performance-gate-a.md`](docs/performance-gate-a.md).

## Sandbox

The app is sandboxed. Any change to lower-level sampling must remain compatible with `Config/MenuBarStats.entitlements`.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for build/test commands and review expectations.

## License

MIT — see [LICENSE](LICENSE).
