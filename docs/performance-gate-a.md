## Gate A profiling workflow

Gate A focuses on the lowest-risk, highest-residency wins:

1. skip Falcon CPU lookup unless the menu bar is rendering `CPU + Memory`
2. skip disk polling when the disk card is hidden

### Build and test

```bash
xcodebuild -project MenuBarStats.xcodeproj \
  -scheme MenuBarStats \
  -destination 'platform=macOS,name=My Mac' \
  build

xcodebuild -project MenuBarStats.xcodeproj \
  -scheme MenuBarStats \
  -destination 'platform=macOS,name=My Mac' \
  test
```

### Package-focused regression loop

```bash
swift test --package-path MenuBarStatsPackage
swift test --package-path MenuBarStatsPackage --filter StatsRefreshCoordinatorTests
```

### Signpost-enabled Instruments scenarios

The app emits signposts for:

- `SummaryRefresh`
- `FalconLookup`
- `DiskRefresh`
- `TopCPUProcessList`
- `TopMemoryProcessList`
- `StatusItemRender`

Use these templates:

- `Time Profiler`
- `Logging`
- `System Trace`
- `Allocations`

If a future Xcode install exposes a dedicated `Points of Interest` template again, it can be used in place of `Logging`.

Mandatory scenarios:

1. closed idle, balanced preset, `CPU + Memory`, 5 minutes
2. closed idle, `CPU %`, 5 minutes
3. closed idle with disk hidden, 5 minutes
4. open popover, balanced preset, 2 minutes
5. open popover, frequent preset, 2 minutes
6. preset switch: light -> balanced -> frequent -> balanced, 2 minutes

Suggested command shape:

```bash
xcrun xctrace record \
  --template 'Logging' \
  --attach <PID> \
  --time-limit 5m \
  --output .omx/artifacts/xctrace/gate-a-closed-idle.trace
```

### Metrics to compare

- app CPU %
- wakeups / timer activity
- child-process launches per minute
- p50 / p95 refresh durations
- resident memory drift
- status-item renders per minute

### Gate A success thresholds

- closed `.iconOnly` / `.cpuPercent`: `0` child-process launches per minute
- disk hidden: `0` disk refresh work items
- closed average app CPU: `<= 0.5%`
- closed resident memory drift over 10 minutes: `<= 10 MB`
