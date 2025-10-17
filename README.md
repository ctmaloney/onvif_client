# OnvifClient

A modern, actively maintained Ruby client for ONVIF-compliant IP cameras. Control your IP cameras with support for device discovery, media streaming, and PTZ (pan/tilt/zoom) controls.

## Features

- 🔍 **Device Discovery** - Automatically find ONVIF cameras on your network
- 📹 **Media Streams** - Get RTSP stream URLs and snapshots
- 🎮 **PTZ Control** - Full pan, tilt, and zoom support
- 🔐 **WS-Security** - Proper digest authentication
- 🚀 **Modern Ruby** - Clean API, Ruby 2.7+
- 📦 **Well Tested** - Comprehensive test coverage

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'onvif_client'
```

And then execute:

```bash
bundle install
```

Or install it yourself:

```bash
gem install onvif_client
```

## Quick Start

```ruby
require 'onvif_client'

# Connect to a camera
camera = OnvifClient.connect(
  host: '192.168.1.100',
  username: 'admin',
  password: 'password'
)

# Get device information
info = camera.get_device_information
puts "Camera: #{info[:manufacturer]} #{info[:model]}"
puts "Firmware: #{info[:firmware_version]}"

# Get capabilities
capabilities = camera.get_capabilities
puts "Media service: #{capabilities[:media][:x_addr]}"
```

## Usage

### Discovering Cameras

Find all ONVIF cameras on your network:

```ruby
# Discover cameras (5 second timeout)
cameras = OnvifClient.discover(timeout: 5)

cameras.each do |device|
  puts "Found camera at #{device[:address]}:#{device[:port]}"
  puts "XAddrs: #{device[:xaddrs]}"
end

# Connect to discovered camera
camera = OnvifClient.connect(
  host: cameras.first[:address],
  username: 'admin',
  password: 'password',
  port: cameras.first[:port]
)
```

### Device Management

```ruby
# Get device information
info = camera.get_device_information
# => { manufacturer: "SUNBA", model: "Performance-Series", ... }

# Get capabilities
capabilities = camera.get_capabilities
# => { analytics: {...}, device: {...}, media: {...}, ptz: {...} }

# Get services
services = camera.get_services
services.each do |service|
  puts "#{service[:namespace]}: #{service[:x_addr]}"
end

# Get system date/time
datetime = camera.get_system_date_time

# Get network interfaces
interfaces = camera.get_network_interfaces

# Get hostname
hostname = camera.get_hostname

# Reboot camera (use with caution!)
camera.system_reboot
```

### Media Streaming

```ruby
# Get media service endpoint
services = camera.get_services
media_service = services.find { |s| s[:namespace].include?("media") }

# Create media client
media = OnvifClient::MediaClient.new(
  endpoint: media_service[:x_addr],
  username: 'admin',
  password: 'password'
)

# Get profiles
profiles = media.get_profiles
main_profile = profiles.first

puts "Profile: #{main_profile[:name]}"
puts "Token: #{main_profile[:token]}"

# Get RTSP stream URL
stream = media.get_stream_uri(
  profile_token: main_profile[:token],
  protocol: "RTSP"
)

puts "Stream URL: #{stream[:uri]}"
# => rtsp://admin:password@192.168.1.100:554/stream1

# Get snapshot URL
snapshot = media.get_snapshot_uri(profile_token: main_profile[:token])
puts "Snapshot URL: #{snapshot[:uri]}"

# Get video sources
sources = media.get_video_sources

# Get video encoder configurations
encoders = media.get_video_encoder_configurations
```

### PTZ Control

```ruby
# Get PTZ service endpoint
services = camera.get_services
ptz_service = services.find { |s| s[:namespace].include?("ptz") }

# Create PTZ client
ptz = OnvifClient::PTZClient.new(
  endpoint: ptz_service[:x_addr],
  username: 'admin',
  password: 'password'
)

# Get profile token (from media profiles)
profile_token = profiles.first[:token]

# Continuous move (pan right, tilt up)
ptz.continuous_move(
  profile_token: profile_token,
  velocity: {
    "PanTilt" => { "@x" => "0.5", "@y" => "0.5" },
    "Zoom" => { "@x" => "0.0" }
  },
  timeout: "PT5S" # Move for 5 seconds
)

# Stop movement
ptz.stop(profile_token: profile_token)

# Absolute move to position
ptz.absolute_move(
  profile_token: profile_token,
  position: {
    "PanTilt" => { "@x" => "0.0", "@y" => "0.0" },
    "Zoom" => { "@x" => "0.0" }
  }
)

# Get PTZ status
status = ptz.get_status(profile_token: profile_token)
puts "Position: #{status[:position]}"

# Go to home position
ptz.goto_home_position(profile_token: profile_token)

# Set current position as home
ptz.set_home_position(profile_token: profile_token)

# Get presets
presets = ptz.get_presets(profile_token: profile_token)

# Create a preset
preset = ptz.set_preset(
  profile_token: profile_token,
  preset_name: "Front Door"
)

# Go to preset
ptz.goto_preset(
  profile_token: profile_token,
  preset_token: preset[:preset_token]
)

# Remove preset
ptz.remove_preset(
  profile_token: profile_token,
  preset_token: preset[:preset_token]
)
```

## Rails Integration

Example service class for Rails:

```ruby
# app/services/camera_service.rb
class CameraService
  def initialize(camera_record)
    @camera = camera_record
    @client = OnvifClient.connect(
      host: @camera.ip_address,
      username: @camera.username,
      password: @camera.password,
      port: @camera.port || 80
    )
  end

  def device_info
    @client.get_device_information
  rescue OnvifClient::Client::Error => e
    Rails.logger.error "Camera error: #{e.message}"
    nil
  end

  def stream_url
    services = @client.get_services
    media_service = services.find { |s| s[:namespace].include?("media") }
    
    media = OnvifClient::MediaClient.new(
      endpoint: media_service[:x_addr],
      username: @camera.username,
      password: @camera.password
    )
    
    profiles = media.get_profiles
    stream = media.get_stream_uri(profile_token: profiles.first[:token])
    stream[:uri]
  end

  def self.discover_cameras
    OnvifClient.discover(timeout: 10)
  end
end

# Usage in controller
class CamerasController < ApplicationController
  def show
    @camera = Camera.find(params[:id])
    service = CameraService.new(@camera)
    @stream_url = service.stream_url
  end

  def discover
    @discovered = CameraService.discover_cameras
    render json: @discovered
  end
end
```

## VLC Playback

Play RTSP streams with VLC:

```bash
vlc rtsp://admin:password@192.168.1.100:554/stream1
```

Or programmatically:

```ruby
stream_url = media.get_stream_uri(profile_token: profile_token)[:uri]
system("vlc #{stream_url}")
```

## Error Handling

```ruby
begin
  camera = OnvifClient.connect(
    host: '192.168.1.100',
    username: 'admin',
    password: 'wrong_password'
  )
  info = camera.get_device_information
rescue OnvifClient::Client::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue OnvifClient::Client::ConnectionError => e
  puts "Connection failed: #{e.message}"
rescue OnvifClient::Client::Error => e
  puts "ONVIF error: #{e.message}"
end
```

## Troubleshooting

### Camera Not Discovered

- Ensure camera is on the same network/subnet
- Check that ONVIF is enabled in camera settings
- Verify firewall allows UDP port 3702
- Try specifying bind address: `OnvifClient.discover(bind_address: "192.168.1.50")`

### Authentication Errors

- Verify username and password are correct
- Check camera web interface to ensure ONVIF authentication is enabled
- Some cameras require enabling "Digest Authentication"

### Connection Timeouts

- Check camera is reachable: `ping 192.168.1.100`
- Verify correct port (usually 80 or 8080)
- Try increasing timeout in discovery

### Stream URL Not Working

- Test stream URL in VLC first
- Some cameras use different path formats:
  - `/stream1`, `/stream2`
  - `/Streaming/Channels/101`
  - `/h264`, `/mjpeg`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run:

```bash
bundle exec rake install
```

## Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/onvif_client/client_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/onvif_client.

### Contribution Guidelines

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests for your changes
4. Make your changes
5. Run the test suite (`bundle exec rspec`)
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

- Built with [Savon](https://www.savonrb.com/) for SOAP support
- Follows [ONVIF Core Specification v20.06](https://www.onvif.org/specs/core/ONVIF-Core-Specification.pdf)
- Implements WS-Discovery for device discovery
- Based on real-world testing with SUNBA and other camera brands

## Related Projects

- [python-onvif-zeep](https://github.com/FalkTannhaeuser/python-onvif-zeep) - Python ONVIF client
- [node-onvif](https://github.com/agsh/onvif) - Node.js ONVIF client
- [onvif-gui](https://github.com/caspermeijn/onvif-gui) - GUI ONVIF browser

## Support

- 📖 [ONVIF Official Documentation](https://www.onvif.org/profiles/)
- 💬 [Open an Issue](https://github.com/yourusername/onvif_client/issues)
- 📧 Contact: your.email@example.com
