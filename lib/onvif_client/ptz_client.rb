require "savon"

module OnvifClient
  class PTZClient
    attr_reader :endpoint, :username, :password, :client, :timeout

    def initialize(endpoint:, username:, password:, timeout: 30)
      @endpoint = endpoint
      @username = username
      @password = password
      @timeout = timeout
      @client = create_soap_client
    end

    # Get PTZ configurations
    def get_configurations
      response = client.call(:get_configurations)
      parse_configurations(response)
    end

    # Get PTZ configuration
    def get_configuration(configuration_token:)
      message = { "tptz:PTZConfigurationToken" => configuration_token }
      response = client.call(:get_configuration, message: message)
      parse_configuration(response.body[:get_configuration_response][:ptz_configuration])
    end

    # Continuous move (for joystick-like control)
    def continuous_move(profile_token:, velocity:, timeout: nil)
      message = {
        "tptz:ProfileToken" => profile_token,
        "tptz:Velocity" => velocity
      }
      message["tptz:Timeout"] = timeout if timeout

      response = client.call(:continuous_move, message: message)
      { success: true }
    end

    # Absolute move to specific position
    def absolute_move(profile_token:, position:, speed: nil)
      message = {
        "tptz:ProfileToken" => profile_token,
        "tptz:Position" => position
      }
      message["tptz:Speed"] = speed if speed

      response = client.call(:absolute_move, message: message)
      { success: true }
    end

    # Relative move from current position
    def relative_move(profile_token:, translation:, speed: nil)
      message = {
        "tptz:ProfileToken" => profile_token,
        "tptz:Translation" => translation
      }
      message["tptz:Speed"] = speed if speed

      response = client.call(:relative_move, message: message)
      { success: true }
    end

    # Stop PTZ movement
    def stop(profile_token:, pan_tilt: true, zoom: true)
      message = {
        "tptz:ProfileToken" => profile_token,
        "tptz:PanTilt" => pan_tilt,
        "tptz:Zoom" => zoom
      }

      response = client.call(:stop, message: message)
      { success: true }
    end

    # Get PTZ status
    def get_status(profile_token:)
      message = { "tptz:ProfileToken" => profile_token }
      response = client.call(:get_status, message: message)
      parse_status(response)
    end

    # Go to home position
    def goto_home_position(profile_token:, speed: nil)
      message = { "tptz:ProfileToken" => profile_token }
      message["tptz:Speed"] = speed if speed

      response = client.call(:goto_home_position, message: message)
      { success: true }
    end

    # Set home position
    def set_home_position(profile_token:)
      message = { "tptz:ProfileToken" => profile_token }
      response = client.call(:set_home_position, message: message)
      { success: true }
    end

    # Get presets
    def get_presets(profile_token:)
      message = { "tptz:ProfileToken" => profile_token }
      response = client.call(:get_presets, message: message)
      parse_presets(response)
    end

    # Set preset
    def set_preset(profile_token:, preset_name: nil, preset_token: nil)
      message = { "tptz:ProfileToken" => profile_token }
      message["tptz:PresetName"] = preset_name if preset_name
      message["tptz:PresetToken"] = preset_token if preset_token

      response = client.call(:set_preset, message: message)
      { preset_token: response.body[:set_preset_response][:preset_token] }
    end

    # Remove preset
    def remove_preset(profile_token:, preset_token:)
      message = {
        "tptz:ProfileToken" => profile_token,
        "tptz:PresetToken" => preset_token
      }

      response = client.call(:remove_preset, message: message)
      { success: true }
    end

    # Goto preset
    def goto_preset(profile_token:, preset_token:, speed: nil)
      message = {
        "tptz:ProfileToken" => profile_token,
        "tptz:PresetToken" => preset_token
      }
      message["tptz:Speed"] = speed if speed

      response = client.call(:goto_preset, message: message)
      { success: true }
    end

    private

    def create_soap_client
      Savon.client(
        endpoint: endpoint,
        namespace: "http://www.onvif.org/ver20/ptz/wsdl",
        env_namespace: :soap,
        namespaces: {
          "xmlns:tptz" => "http://www.onvif.org/ver20/ptz/wsdl",
          "xmlns:tt" => "http://www.onvif.org/ver10/schema"
        },
        wsse_auth: [username, password, :digest],
        convert_request_keys_to: :camelcase,
        pretty_print_xml: false,
        log: false,
        open_timeout: timeout,
        read_timeout: timeout
      )
    end

    def parse_configurations(response)
      configs_data = response.body[:get_configurations_response][:ptz_configuration]
      configs = configs_data.is_a?(Array) ? configs_data : [configs_data]

      configs.map { |config| parse_configuration(config) }
    end

    def parse_configuration(config)
      {
        token: config[:@token],
        name: config[:name],
        use_count: config[:use_count],
        node_token: config[:node_token],
        default_absolute_pant_tilt_position_space: config[:default_absolute_pant_tilt_position_space],
        default_absolute_zoom_position_space: config[:default_absolute_zoom_position_space],
        default_relative_pan_tilt_translation_space: config[:default_relative_pan_tilt_translation_space],
        default_relative_zoom_translation_space: config[:default_relative_zoom_translation_space],
        default_continuous_pan_tilt_velocity_space: config[:default_continuous_pan_tilt_velocity_space],
        default_continuous_zoom_velocity_space: config[:default_continuous_zoom_velocity_space],
        default_ptz_speed: config[:default_ptz_speed],
        default_ptz_timeout: config[:default_ptz_timeout],
        pan_tilt_limits: config[:pan_tilt_limits],
        zoom_limits: config[:zoom_limits]
      }
    end

    def parse_status(response)
      status = response.body[:get_status_response][:ptz_status]
      {
        position: status[:position],
        move_status: status[:move_status],
        error: status[:error],
        utc_time: status[:utc_time]
      }
    end

    def parse_presets(response)
      presets_data = response.body[:get_presets_response][:preset]
      return [] unless presets_data
      
      presets = presets_data.is_a?(Array) ? presets_data : [presets_data]

      presets.map do |preset|
        {
          token: preset[:@token],
          name: preset[:name],
          ptz_position: preset[:ptz_position]
        }
      end
    end
  end
end
