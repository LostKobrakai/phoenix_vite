# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.3] - 2026-04-14

- Rebuild JS on publishing to hex

## [0.4.2] - 2026-03-06

- Support ts/tsx/jsx referenced files [[#24](https://github.com/LostKobrakai/phoenix_vite/issues/24)]
- Allow setting crossorigin attributes for generated links/scripts

## [0.4.1] - 2026-02-19

- Remove url cache parameter from chunks [[#22](https://github.com/LostKobrakai/phoenix_vite/issues/22)]

## [0.4.0] - 2025-09-18

- Update to `:bun` `~> 1.5 and >= 1.5.1` for not stopping given the changes in 0.3.0 [[#18](https://github.com/LostKobrakai/phoenix_vite/issues/18)]
- Update tests for `:phoenix` 1.8.1 generators

## [0.3.3] - 2025-08-22

- Make node work with the colocated aliases [[#16](https://github.com/LostKobrakai/phoenix_vite/issues/16)]
- Replaced `@conn` with endpoint module on the logo in the layout

## [0.3.2] - 2025-08-16

- Update codebase for release version phoenix 1.8 generators
- Add aliases for live view colocated js

## [0.3.1] - 2025-08-14

- Publish to hex including package.json ([#15](https://github.com/LostKobrakai/phoenix_vite/issues/15))

## [0.3.0] - 2025-08-11

- Update app layout known static assets ([#1](https://github.com/LostKobrakai/phoenix_vite/issues/1))
- Ship a small vite plugin
  - properly shut down when using npm ([#7](https://github.com/LostKobrakai/phoenix_vite/issues/7))
  - Make HMR with `:phoenix_live_reload`s `:notify` work ([#8](https://github.com/LostKobrakai/phoenix_vite/issues/8))
- Fixed mix task when igniter is not available
- Generate vite optimization config ([#9](https://github.com/LostKobrakai/phoenix_vite/issues/9))

## [0.2.2] - 2025-07-03

- Fix manifest references for production environment ([#4](https://github.com/LostKobrakai/phoenix_vite/pull/4))

## [0.2.1] - 2025-06-23

- Use `:bun` version 1.5 with the changes to `bun x`

## [0.2.0] - 2025-06-22

- Support local node/npm setups
- Split up igniter steps and add more tests

## [0.1.0] - 2025-06-22

### Added

- Components to handle vite assets both for the dev server as well as from a manifest
- Integration with bun elixir package
- Igniter installer

[unreleased]: https://github.com/LostKobrakai/phoenix_vite/compare/v0.4.3...HEAD
[0.4.3]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.4.3
[0.4.2]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.4.2
[0.4.1]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.4.1
[0.4.0]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.4.0
[0.3.3]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.3.3
[0.3.2]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.3.2
[0.3.1]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.3.1
[0.3.0]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.3.0
[0.2.2]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.2.2
[0.2.1]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.2.1
[0.2.0]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.2.0
[0.1.0]: https://github.com/LostKobrakai/phoenix_vite/releases/tag/v0.1.0
