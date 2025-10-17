require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end if ENV['COVERAGE']

require "onvif_client"
require "webmock/rspec"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = { record: :new_episodes }
  
  # Filter sensitive data
  config.filter_sensitive_data('<USERNAME>') { ENV['CAMERA_USER'] || 'admin' }
  config.filter_sensitive_data('<PASSWORD>') { ENV['CAMERA_PASS'] || 'password' }
  config.filter_sensitive_data('<HOST>') { ENV['CAMERA_HOST'] || '192.168.1.100' }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order to surface order dependencies
  config.order = :random
  
  # Seed global randomization in this process using the `--seed` CLI option
  Kernel.srand config.seed
end
