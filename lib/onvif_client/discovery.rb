require "socket"
require "timeout"
require "securerandom"
require "nokogiri"

module OnvifClient
  class Discovery
    WS_DISCOVERY_MULTICAST_ADDRESS = "239.255.255.250"
    WS_DISCOVERY_PORT = 3702
    DEFAULT_TIMEOUT = 5

    # Discover ONVIF devices on the network
    def self.discover(timeout: DEFAULT_TIMEOUT, bind_address: "0.0.0.0")
      new.discover(timeout: timeout, bind_address: bind_address)
    end

    def discover(timeout: DEFAULT_TIMEOUT, bind_address: "0.0.0.0")
      devices = []
      
      socket = create_multicast_socket(bind_address)
      send_probe_message(socket)
      
      Timeout.timeout(timeout) do
        loop do
          data, addr = socket.recvfrom(65536)
          device = parse_probe_match(data, addr)
          devices << device if device && !devices.any? { |d| d[:address] == device[:address] }
        end
      end
    rescue Timeout::Error
      devices
    ensure
      socket.close if socket
    end

    private

    def create_multicast_socket(bind_address)
      socket = UDPSocket.new
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
      
      # Enable SO_REUSEPORT on platforms that support it
      begin
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEPORT, 1)
      rescue
        # Not supported on all platforms
      end
      
      socket.bind(bind_address, 0)
      
      # Join multicast group
      ip_mreq = IPAddr.new(WS_DISCOVERY_MULTICAST_ADDRESS).hton + 
                IPAddr.new(bind_address).hton
      socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip_mreq)
      
      socket
    end

    def send_probe_message(socket)
      message_id = "uuid:#{SecureRandom.uuid}"
      
      probe_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope 
          xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
          xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing"
          xmlns:wsd="http://schemas.xmlsoap.org/ws/2005/04/discovery"
          xmlns:wsdp="http://schemas.xmlsoap.org/ws/2006/02/devprof">
          <soap:Header>
            <wsa:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</wsa:Action>
            <wsa:MessageID>#{message_id}</wsa:MessageID>
            <wsa:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</wsa:To>
          </soap:Header>
          <soap:Body>
            <wsd:Probe>
              <wsd:Types>wsdp:Device</wsd:Types>
            </wsd:Probe>
          </soap:Body>
        </soap:Envelope>
      XML

      socket.send(probe_xml, 0, WS_DISCOVERY_MULTICAST_ADDRESS, WS_DISCOVERY_PORT)
    end

    def parse_probe_match(data, addr)
      doc = Nokogiri::XML(data)
      
      # Check if this is a ProbeMatch response
      probe_match = doc.at_xpath("//wsd:ProbeMatch", "wsd" => "http://schemas.xmlsoap.org/ws/2005/04/discovery")
      return nil unless probe_match

      xaddrs = probe_match.at_xpath(".//wsd:XAddrs", "wsd" => "http://schemas.xmlsoap.org/ws/2005/04/discovery")
      return nil unless xaddrs

      # Parse XAddrs (can be multiple URLs separated by spaces)
      addresses = xaddrs.text.strip.split(/\s+/)
      primary_address = addresses.first

      # Extract host and port from URL
      uri = URI.parse(primary_address)
      
      {
        address: uri.host,
        port: uri.port || 80,
        xaddrs: addresses,
        types: parse_types(probe_match),
        scopes: parse_scopes(probe_match),
        endpoint_reference: parse_endpoint_reference(probe_match)
      }
    rescue => e
      nil
    end

    def parse_types(probe_match)
      types_node = probe_match.at_xpath(".//wsd:Types", "wsd" => "http://schemas.xmlsoap.org/ws/2005/04/discovery")
      return [] unless types_node
      
      types_node.text.strip.split(/\s+/)
    end

    def parse_scopes(probe_match)
      scopes_node = probe_match.at_xpath(".//wsd:Scopes", "wsd" => "http://schemas.xmlsoap.org/ws/2005/04/discovery")
      return [] unless scopes_node
      
      scopes_text = scopes_node.text.strip
      scopes_text.split(/\s+/).map do |scope|
        parse_scope_attributes(scope)
      end.compact
    end

    def parse_scope_attributes(scope)
      # ONVIF scopes contain device information
      # Example: onvif://www.onvif.org/name/SUNBA
      # Example: onvif://www.onvif.org/hardware/Performance-Series
      
      return nil unless scope.start_with?("onvif://")
      
      uri = URI.parse(scope)
      path_parts = uri.path.split("/").reject(&:empty?)
      
      {
        type: path_parts[0],
        value: path_parts[1]
      } if path_parts.length >= 2
    rescue
      nil
    end

    def parse_endpoint_reference(probe_match)
      endpoint_ref = probe_match.at_xpath(".//wsa:EndpointReference/wsa:Address", 
                                          "wsa" => "http://schemas.xmlsoap.org/ws/2004/08/addressing")
      endpoint_ref&.text&.strip
    end
  end
end
