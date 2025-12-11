require "savon"

module OnvifClient
  class MediaClient
    attr_reader :endpoint, :username, :password, :client

    def initialize(endpoint:, username:, password:)
      @endpoint = endpoint
      @username = username
      @password = password
      @client = create_soap_client
    end

    # Get all media profiles
    def get_profiles
      response = client.call(:get_profiles)
      parse_profiles(response)
    end

    # Get stream URI for a profile
    def get_stream_uri(profile_token:, protocol: "RTSP")
      message = {
        "trt:ProfileToken" => profile_token,
        "trt:StreamSetup" => {
          stream: protocol,
          transport: {
            protocol: protocol
          }
        }
      }

      response = client.call(:get_stream_uri, message: message)
      parse_stream_uri(response)
    end

    # Get snapshot URI
    def get_snapshot_uri(profile_token:)
      message = { "trt:ProfileToken" => profile_token }
      response = client.call(:get_snapshot_uri, message: message)
      parse_snapshot_uri(response)
    end

    # Get video sources
    def get_video_sources
      response = client.call(:get_video_sources)
      parse_video_sources(response)
    end

    # Get video source configurations
    def get_video_source_configurations
      response = client.call(:get_video_source_configurations)
      parse_video_source_configurations(response)
    end

    # Get video encoder configurations
    def get_video_encoder_configurations
      response = client.call(:get_video_encoder_configurations)
      parse_video_encoder_configurations(response)
    end

    # Get audio sources
    def get_audio_sources
      response = client.call(:get_audio_sources)
      parse_audio_sources(response)
    rescue Savon::SOAPFault => e
      # Audio not supported on all cameras
      return [] if e.message.include?("ActionNotSupported")
      raise
    end

    # Get audio encoder configurations
    def get_audio_encoder_configurations
      response = client.call(:get_audio_encoder_configurations)
      parse_audio_encoder_configurations(response)
    rescue Savon::SOAPFault => e
      return [] if e.message.include?("ActionNotSupported")
      raise
    end

    private

    def create_soap_client
      Savon.client(
        endpoint: endpoint,
        namespace: "http://www.onvif.org/ver10/media/wsdl",
        env_namespace: :soap,
        namespaces: {
          "xmlns:trt" => "http://www.onvif.org/ver10/media/wsdl",
          "xmlns:tt" => "http://www.onvif.org/ver10/schema"
        },
        wsse_auth: [username, password, :digest],
        convert_request_keys_to: :camelcase,
        pretty_print_xml: false,
        log: false
      )
    end

    def parse_profiles(response)
      profiles_data = response.body[:get_profiles_response][:profiles]
      profiles = profiles_data.is_a?(Array) ? profiles_data : [profiles_data]

      profiles.map do |profile|
        {
          token: profile[:@token],
          fixed: profile[:@fixed],
          name: profile[:name],
          video_source_configuration: parse_configuration(profile[:video_source_configuration]),
          video_encoder_configuration: parse_configuration(profile[:video_encoder_configuration]),
          audio_source_configuration: parse_configuration(profile[:audio_source_configuration]),
          audio_encoder_configuration: parse_configuration(profile[:audio_encoder_configuration]),
          ptz_configuration: parse_configuration(profile[:ptz_configuration])
        }
      end
    end

    def parse_configuration(config)
      return nil unless config

      {
        token: config[:@token],
        name: config[:name],
        use_count: config[:use_count]
      }.merge(config.except(:@token, :name, :use_count))
    end

    def parse_stream_uri(response)
      body = response.body[:get_stream_uri_response][:media_uri]
      {
        uri: body[:uri],
        invalid_after_connect: body[:invalid_after_connect],
        invalid_after_reboot: body[:invalid_after_reboot],
        timeout: body[:timeout]
      }
    end

    def parse_snapshot_uri(response)
      body = response.body[:get_snapshot_uri_response][:media_uri]
      {
        uri: body[:uri],
        invalid_after_connect: body[:invalid_after_connect],
        invalid_after_reboot: body[:invalid_after_reboot],
        timeout: body[:timeout]
      }
    end

    def parse_video_sources(response)
      sources_data = response.body[:get_video_sources_response][:video_sources]
      sources = sources_data.is_a?(Array) ? sources_data : [sources_data]

      sources.map do |source|
        {
          token: source[:@token],
          framerate: source[:framerate],
          resolution: source[:resolution]
        }
      end
    end

    def parse_video_source_configurations(response)
      configs_data = response.body[:get_video_source_configurations_response][:configurations]
      configs = configs_data.is_a?(Array) ? configs_data : [configs_data]

      configs.map { |config| parse_configuration(config) }
    end

    def parse_video_encoder_configurations(response)
      configs_data = response.body[:get_video_encoder_configurations_response][:configurations]
      configs = configs_data.is_a?(Array) ? configs_data : [configs_data]

      configs.map { |config| parse_configuration(config) }
    end

    def parse_audio_sources(response)
      sources_data = response.body[:get_audio_sources_response][:audio_sources]
      return [] unless sources_data
      
      sources = sources_data.is_a?(Array) ? sources_data : [sources_data]
      sources.map { |source| parse_configuration(source) }
    end

    def parse_audio_encoder_configurations(response)
      configs_data = response.body[:get_audio_encoder_configurations_response][:configurations]
      return [] unless configs_data
      
      configs = configs_data.is_a?(Array) ? configs_data : [configs_data]
      configs.map { |config| parse_configuration(config) }
    end
  end
end
