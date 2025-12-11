require "savon"
require "httpclient"
require "nokogiri"
require "base64"
require "digest"
require "securerandom"
require "time"

module OnvifClient
  class Client
    class Error < StandardError; end
    class ConnectionError < Error; end
    class AuthenticationError < Error; end
    class NotSupportedError < Error; end

    attr_reader :host, :port, :username, :password, :device_client

    def initialize(host:, username:, password:, port: 80)
      @host = host
      @port = port
      @username = username
      @password = password
      @device_client = create_soap_client(device_service_url)
    end

    # Get device information
    def get_device_information
      response = device_client.call(:get_device_information)
      parse_device_information(response)
    rescue Savon::SOAPFault => e
      raise AuthenticationError, "Authentication failed: #{e.message}" if e.message.include?("Unauthorized")
      raise Error, "SOAP fault: #{e.message}"
    rescue Savon::HTTPError => e
      raise ConnectionError, "Connection failed: #{e.message}"
    rescue StandardError => e
      raise Error, "Unexpected error: #{e.class} - #{e.message}"
    end

    # Get capabilities
    def get_capabilities(category: "All")
      message = { "wsdl:Category" => category }
      response = device_client.call(:get_capabilities, message: message)
      parse_capabilities(response)
    end

    # Get services
    def get_services(include_capability: true)
      message = { "wsdl:IncludeCapability" => include_capability }
      response = device_client.call(:get_services, message: message)
      parse_services(response)
    end

    # Get system date and time
    def get_system_date_time
      response = device_client.call(:get_system_date_time)
      parse_system_date_time(response)
    end

    # Get network interfaces
    def get_network_interfaces
      response = device_client.call(:get_network_interfaces)
      parse_network_interfaces(response)
    end

    # Get hostname
    def get_hostname
      response = device_client.call(:get_hostname)
      parse_hostname(response)
    end

    # Get DNS
    def get_dns
      response = device_client.call(:get_dns)
      parse_dns(response)
    end

    # Get network protocols
    def get_network_protocols
      response = device_client.call(:get_network_protocols)
      parse_network_protocols(response)
    end

    # Reboot device
    def system_reboot
      response = device_client.call(:system_reboot)
      { message: response.body[:system_reboot_response][:message] }
    end

    private

    def device_service_url
      "http://#{host}:#{port}/onvif/device_service"
    end

    def create_soap_client(endpoint, namespace: "http://www.onvif.org/ver10/device/wsdl")
      Savon.client(
        endpoint: endpoint,
        namespace: namespace,
        env_namespace: :soap,
        wsse_auth: [username, password, :digest],
        convert_request_keys_to: :camelcase,
        pretty_print_xml: false,
        log: false
      )
    end

    def parse_device_information(response)
      body = response.body[:get_device_information_response]
      {
        manufacturer: body[:manufacturer],
        model: body[:model],
        firmware_version: body[:firmware_version],
        serial_number: body[:serial_number],
        hardware_id: body[:hardware_id]
      }
    end

    def parse_capabilities(response)
      body = response.body[:get_capabilities_response][:capabilities]
      capabilities = {}

      body.each do |key, value|
        next if key == :"@xmlns:tt"
        capabilities[key] = parse_capability_section(value)
      end

      capabilities
    end

    def parse_capability_section(section)
      return section unless section.is_a?(Hash)

      result = {}
      section.each do |key, value|
        if key == :x_addr
          result[:x_addr] = value
        elsif value.is_a?(Hash)
          result[key] = parse_capability_section(value)
        else
          result[key] = value
        end
      end
      result
    end

    def parse_services(response)
      services_data = response.body[:get_services_response][:service]
      services = services_data.is_a?(Array) ? services_data : [services_data]

      services.map do |service|
        {
          namespace: service[:namespace],
          x_addr: service[:x_addr],
          version: {
            major: service[:version][:major],
            minor: service[:version][:minor]
          },
          capabilities: service[:capabilities]
        }
      end
    end

    def parse_system_date_time(response)
      body = response.body[:get_system_date_time_response][:system_date_and_time]
      
      if body[:utc_date_time]
        utc = body[:utc_date_time]
        {
          date_time_type: body[:date_time_type],
          daylight_savings: body[:daylight_savings],
          time_zone: body[:time_zone],
          utc_date_time: {
            date: {
              year: utc[:date][:year],
              month: utc[:date][:month],
              day: utc[:date][:day]
            },
            time: {
              hour: utc[:time][:hour],
              minute: utc[:time][:minute],
              second: utc[:time][:second]
            }
          }
        }
      else
        body
      end
    end

    def parse_network_interfaces(response)
      interfaces_data = response.body[:get_network_interfaces_response][:network_interfaces]
      interfaces = interfaces_data.is_a?(Array) ? interfaces_data : [interfaces_data]

      interfaces.map do |interface|
        {
          token: interface[:@token],
          enabled: interface[:enabled],
          info: interface[:info],
          ipv4: interface[:i_pv4],
          ipv6: interface[:i_pv6]
        }
      end
    end

    def parse_hostname(response)
      body = response.body[:get_hostname_response][:hostname_information]
      {
        from_dhcp: body[:from_dhcp],
        name: body[:name]
      }
    end

    def parse_dns(response)
      body = response.body[:get_dns_response][:dns_information]
      {
        from_dhcp: body[:from_dhcp],
        dns_from_dhcp: body[:dns_from_dhcp],
        dns_manual: body[:dns_manual]
      }
    end

    def parse_network_protocols(response)
      protocols_data = response.body[:get_network_protocols_response][:network_protocols]
      protocols = protocols_data.is_a?(Array) ? protocols_data : [protocols_data]

      protocols.map do |protocol|
        {
          name: protocol[:name],
          enabled: protocol[:enabled],
          port: protocol[:port]
        }
      end
    end
  end
end
