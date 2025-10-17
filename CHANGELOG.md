# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-10-16

### Added
- Initial release
- Device discovery via WS-Discovery
- Device management (information, capabilities, services)
- Media client for stream URLs and snapshots
- PTZ client for camera control
- Full WS-Security digest authentication support
- Comprehensive documentation and examples
- Support for Ruby 2.7+

### Features
- `OnvifClient::Client` - Main device client
- `OnvifClient::MediaClient` - Media streaming and snapshots
- `OnvifClient::PTZClient` - Pan/tilt/zoom controls
- `OnvifClient::Discovery` - Network camera discovery
- Convenience methods: `OnvifClient.connect` and `OnvifClient.discover`

[Unreleased]: https://github.com/yourusername/onvif_client/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/onvif_client/releases/tag/v0.1.0
