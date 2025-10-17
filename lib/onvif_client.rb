require_relative "onvif_client/version"
require_relative "onvif_client/client"
require_relative "onvif_client/media_client"
require_relative "onvif_client/ptz_client"
require_relative "onvif_client/discovery"

module OnvifClient
  class Error < StandardError; end

  # Convenience method to discover cameras
  def self.discover(timeout: 5, bind_address: "0.0.0.0")
    Discovery.discover(timeout: timeout, bind_address: bind_address)
  end

  # Convenience method to create a client
  def self.connect(host:, username:, password:, port: 80)
    Client.new(host: host, username: username, password: password, port: port)
  end
end
