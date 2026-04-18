# Contributing

Thanks for your interest in MenuBarStats. This is a small project; the bar for contributions is simple:

- Keep diffs small and focused.
- Keep the app sandboxed and signing-free for local builds.
- Keep refresh logic inside the `MenuBarStatsFeature` package.
- Keep host-only concerns (preferences, launch-at-login, status item) in `MenuBarStats/App/`.

## Development loop

```bash
# Fast package-only tests
swift test --package-path MenuBarStatsPackage

# Full app + host tests
xcodebuild -project MenuBarStats.xcodeproj \
  -scheme MenuBarStats \
  -destination 'platform=macOS,name=My Mac' \
  test
```

Please run the full suite before opening a PR.

## Performance work

Changes to sampling cadence, process enumeration, or anything that runs on every refresh should be validated with the profiling workflow in [`docs/performance-gate-a.md`](docs/performance-gate-a.md). Include before/after numbers in the PR when relevant.

## Pull requests

- Title: short, imperative (e.g. "Reduce process-list allocations").
- Description: what changed, why, and — for behavior changes — how you verified it.
- One logical change per PR when possible.

## Reporting bugs

Open an issue with:

- macOS version
- Steps to reproduce
- Expected vs. actual behavior
- Relevant Console / signpost output if you have it

## License

By contributing, you agree that your contributions will be licensed under the MIT License (see [LICENSE](LICENSE)).
