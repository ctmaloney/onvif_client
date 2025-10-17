require "spec_helper"

RSpec.describe OnvifClient::Client do
  let(:host) { "192.168.1.100" }
  let(:username) { "admin" }
  let(:password) { "password" }
  let(:port) { 80 }

  subject(:client) do
    described_class.new(
      host: host,
      username: username,
      password: password,
      port: port
    )
  end

  describe "#initialize" do
    it "sets the host" do
      expect(client.host).to eq(host)
    end

    it "sets the username" do
      expect(client.username).to eq(username)
    end

    it "sets the password" do
      expect(client.password).to eq(password)
    end

    it "sets the port" do
      expect(client.port).to eq(port)
    end

    it "creates a device client" do
      expect(client.device_client).to be_a(Savon::Client)
    end
  end

  describe "#get_device_information" do
    let(:soap_response) do
      {
        get_device_information_response: {
          manufacturer: "SUNBA",
          model: "Performance-Series",
          firmware_version: "QIPC-B2202.10.17.C06222.L61.NB.250307",
          serial_number: "210231T2H6323C000005",
          hardware_id: "Performance-Series"
        }
      }
    end

    before do
      allow_any_instance_of(Savon::Client).to receive(:call)
        .with(:get_device_information)
        .and_return(double(body: soap_response))
    end

    it "returns device information" do
      info = client.get_device_information
      
      expect(info[:manufacturer]).to eq("SUNBA")
      expect(info[:model]).to eq("Performance-Series")
      expect(info[:firmware_version]).to eq("QIPC-B2202.10.17.C06222.L61.NB.250307")
      expect(info[:serial_number]).to eq("210231T2H6323C000005")
      expect(info[:hardware_id]).to eq("Performance-Series")
    end
  end

  describe "#get_capabilities" do
    let(:soap_response) do
      {
        get_capabilities_response: {
          capabilities: {
            analytics: { x_addr: "http://192.168.1.100/onvif/analytics" },
            device: { x_addr: "http://192.168.1.100/onvif/device_service" },
            media: { x_addr: "http://192.168.1.100/onvif/media_service" },
            ptz: { x_addr: "http://192.168.1.100/onvif/ptz" }
          }
        }
      }
    end

    before do
      allow_any_instance_of(Savon::Client).to receive(:call)
        .with(:get_capabilities, message: { "Category" => "All" })
        .and_return(double(body: soap_response))
    end

    it "returns capabilities" do
      capabilities = client.get_capabilities
      
      expect(capabilities[:analytics][:x_addr]).to eq("http://192.168.1.100/onvif/analytics")
      expect(capabilities[:device][:x_addr]).to eq("http://192.168.1.100/onvif/device_service")
      expect(capabilities[:media][:x_addr]).to eq("http://192.168.1.100/onvif/media_service")
      expect(capabilities[:ptz][:x_addr]).to eq("http://192.168.1.100/onvif/ptz")
    end
  end

  describe "#get_services" do
    let(:soap_response) do
      {
        get_services_response: {
          service: [
            {
              namespace: "http://www.onvif.org/ver10/device/wsdl",
              x_addr: "http://192.168.1.100/onvif/device_service",
              version: { major: 20, minor: 6 },
              capabilities: nil
            },
            {
              namespace: "http://www.onvif.org/ver10/media/wsdl",
              x_addr: "http://192.168.1.100/onvif/media_service",
              version: { major: 20, minor: 6 },
              capabilities: nil
            }
          ]
        }
      }
    end

    before do
      allow_any_instance_of(Savon::Client).to receive(:call)
        .with(:get_services, message: { "IncludeCapability" => true })
        .and_return(double(body: soap_response))
    end

    it "returns services" do
      services = client.get_services
      
      expect(services.size).to eq(2)
      expect(services[0][:namespace]).to eq("http://www.onvif.org/ver10/device/wsdl")
      expect(services[1][:namespace]).to eq("http://www.onvif.org/ver10/media/wsdl")
    end
  end

  describe "error handling" do
    context "when authentication fails" do
      before do
        allow_any_instance_of(Savon::Client).to receive(:call)
          .and_raise(Savon::SOAPFault.new(double(to_hash: {}, to_s: "Unauthorized")))
      end

      it "raises AuthenticationError" do
        expect { client.get_device_information }.to raise_error(OnvifClient::Client::AuthenticationError)
      end
    end

    context "when connection fails" do
      before do
        allow_any_instance_of(Savon::Client).to receive(:call)
          .and_raise(Savon::HTTPError.new(double(code: 500)))
      end

      it "raises ConnectionError" do
        expect { client.get_device_information }.to raise_error(OnvifClient::Client::ConnectionError)
      end
    end
  end
end
