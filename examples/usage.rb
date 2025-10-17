#!/usr/bin/env ruby

require "bundler/setup"
require "onvif_client"

# Example 1: Discover cameras on the network
puts "=" * 50
puts "Example 1: Discovering Cameras"
puts "=" * 50

cameras = OnvifClient.discover(timeout: 5)

if cameras.empty?
  puts "No cameras found!"
  puts "\nMake sure:"
  puts "  - Camera is powered on and connected to network"
  puts "  - ONVIF is enabled in camera settings"
  puts "  - Camera is on the same network as this computer"
  puts "  - Firewall allows UDP port 3702"
else
  puts "Found #{cameras.size} camera(s):"
  cameras.each_with_index do |camera, i|
    puts "\nCamera #{i + 1}:"
    puts "  Address: #{camera[:address]}:#{camera[:port]}"
    puts "  XAddrs: #{camera[:xaddrs].join(', ')}"
    puts "  Types: #{camera[:types].join(', ')}"
  end
end

# Example 2: Connect to a specific camera
puts "\n" + "=" * 50
puts "Example 2: Connecting to Camera"
puts "=" * 50

# Update these with your camera details
CAMERA_HOST = ENV['CAMERA_HOST'] || '192.168.4.131'
CAMERA_USER = ENV['CAMERA_USER'] || 'admin'
CAMERA_PASS = ENV['CAMERA_PASS'] || 'password'

begin
  puts "\nConnecting to #{CAMERA_HOST}..."
  
  camera = OnvifClient.connect(
    host: CAMERA_HOST,
    username: CAMERA_USER,
    password: CAMERA_PASS
  )
  
  # Get device information
  puts "\n📹 Device Information:"
  info = camera.get_device_information
  puts "  Manufacturer: #{info[:manufacturer]}"
  puts "  Model: #{info[:model]}"
  puts "  Firmware: #{info[:firmware_version]}"
  puts "  Serial: #{info[:serial_number]}"
  puts "  Hardware ID: #{info[:hardware_id]}"
  
  # Get capabilities
  puts "\n⚙️  Capabilities:"
  capabilities = camera.get_capabilities
  
  capabilities.each do |name, cap|
    next unless cap.is_a?(Hash) && cap[:x_addr]
    puts "  #{name.to_s.capitalize}: #{cap[:x_addr]}"
  end
  
  # Get services
  puts "\n🔧 Services:"
  services = camera.get_services
  
  services.each do |service|
    service_type = service[:namespace].split('/').last
    puts "  #{service_type}: #{service[:x_addr]}"
  end
  
  # Example 3: Get stream URL
  puts "\n" + "=" * 50
  puts "Example 3: Getting Stream URL"
  puts "=" * 50
  
  media_service = services.find { |s| s[:namespace].include?("media") }
  
  if media_service
    puts "\nMedia service found at: #{media_service[:x_addr]}"
    
    media = OnvifClient::MediaClient.new(
      endpoint: media_service[:x_addr],
      username: CAMERA_USER,
      password: CAMERA_PASS
    )
    
    # Get profiles
    profiles = media.get_profiles
    puts "\n📺 Available Profiles:"
    profiles.each_with_index do |profile, i|
      puts "\n  Profile #{i + 1}:"
      puts "    Name: #{profile[:name]}"
      puts "    Token: #{profile[:token]}"
      puts "    Fixed: #{profile[:fixed]}"
    end
    
    # Get stream URI for first profile
    main_profile = profiles.first
    stream = media.get_stream_uri(
      profile_token: main_profile[:token],
      protocol: "RTSP"
    )
    
    puts "\n🎬 RTSP Stream URL:"
    puts "  #{stream[:uri]}"
    puts "\n  To view in VLC, run:"
    puts "  vlc #{stream[:uri]}"
    
    # Get snapshot URI
    snapshot = media.get_snapshot_uri(profile_token: main_profile[:token])
    puts "\n📸 Snapshot URL:"
    puts "  #{snapshot[:uri]}"
    
  else
    puts "Media service not available on this camera"
  end
  
  # Example 4: PTZ Control (if available)
  puts "\n" + "=" * 50
  puts "Example 4: PTZ Control"
  puts "=" * 50
  
  ptz_service = services.find { |s| s[:namespace].include?("ptz") }
  
  if ptz_service
    puts "\nPTZ service found at: #{ptz_service[:x_addr]}"
    
    ptz = OnvifClient::PTZClient.new(
      endpoint: ptz_service[:x_addr],
      username: CAMERA_USER,
      password: CAMERA_PASS
    )
    
    profile_token = profiles.first[:token]
    
    # Get PTZ configurations
    configs = ptz.get_configurations
    puts "\n🎮 PTZ Configurations:"
    configs.each do |config|
      puts "  Name: #{config[:name]}"
      puts "  Token: #{config[:token]}"
    end
    
    # Get current status
    status = ptz.get_status(profile_token: profile_token)
    puts "\n📍 Current PTZ Status:"
    puts "  Position: #{status[:position]}"
    puts "  Move Status: #{status[:move_status]}"
    
    # Get presets
    presets = ptz.get_presets(profile_token: profile_token)
    if presets.any?
      puts "\n🔖 Saved Presets:"
      presets.each do |preset|
        puts "  #{preset[:name]} (#{preset[:token]})"
      end
    else
      puts "\n🔖 No presets saved"
    end
    
  else
    puts "\nPTZ service not available on this camera"
  end
  
  # Example 5: System Information
  puts "\n" + "=" * 50
  puts "Example 5: System Information"
  puts "=" * 50
  
  # Get date/time
  datetime = camera.get_system_date_time
  puts "\n🕐 System Date/Time:"
  puts "  Type: #{datetime[:date_time_type]}"
  puts "  Timezone: #{datetime[:time_zone]}"
  if datetime[:utc_date_time]
    utc = datetime[:utc_date_time]
    puts "  UTC: #{utc[:date][:year]}-#{utc[:date][:month]}-#{utc[:date][:day]} " \
         "#{utc[:time][:hour]}:#{utc[:time][:minute]}:#{utc[:time][:second]}"
  end
  
  # Get hostname
  hostname = camera.get_hostname
  puts "\n🏷️  Hostname:"
  puts "  Name: #{hostname[:name]}"
  puts "  From DHCP: #{hostname[:from_dhcp]}"
  
  # Get network interfaces
  interfaces = camera.get_network_interfaces
  puts "\n🌐 Network Interfaces:"
  interfaces.each do |interface|
    puts "  Token: #{interface[:token]}"
    puts "  Enabled: #{interface[:enabled]}"
    puts "  IPv4: #{interface[:ipv4]}"
  end
  
rescue OnvifClient::Client::AuthenticationError => e
  puts "\n❌ Authentication failed!"
  puts "Error: #{e.message}"
  puts "\nPlease check:"
  puts "  - Username is correct"
  puts "  - Password is correct"
  puts "  - ONVIF authentication is enabled on camera"
  
rescue OnvifClient::Client::ConnectionError => e
  puts "\n❌ Connection failed!"
  puts "Error: #{e.message}"
  puts "\nPlease check:"
  puts "  - Camera IP address is correct"
  puts "  - Camera is powered on and connected"
  puts "  - Network connectivity (try: ping #{CAMERA_HOST})"
  puts "  - Firewall settings"
  
rescue OnvifClient::Client::Error => e
  puts "\n❌ ONVIF error!"
  puts "Error: #{e.message}"
  
rescue => e
  puts "\n❌ Unexpected error!"
  puts "Error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 50
puts "Done!"
puts "=" * 50
