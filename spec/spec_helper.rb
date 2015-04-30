# you are encouraged to keep this file as
# light-weight as possible. Requiring heavyweight dependencies from this file
# will add to the boot time of your test suite on EVERY test run, even for an
# individual file that may not need all of that loaded. Instead, make a
# separate helper file that requires this one and then use it only in the specs
# that actually need it.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
ENV["RAILS_ENV"] ||= 'test'
ENV["RSPEC_RUNNING"] = 'true'

require 'coveralls'
Coveralls.wear!

require 'engine_cart'
EngineCart.load_application!

require 'triannon'
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/rspec'

=begin
RSpec.configure do |config|
# The settings below are suggested to provide a good initial experience
# with RSpec, but feel free to customize to your heart's content.

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended.
    mocks.verify_partial_doubles = true
  end
end
=end

module Triannon
  def self.fixture_path path
    File.expand_path(File.dirname(__FILE__) + "/fixtures/#{path}")
  end
  def self.annotation_fixture fixture
    File.read Triannon.fixture_path("annotations/#{fixture}")
  end
end

require 'vcr'
VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
  c.default_cassette_options = {:record => :new_episodes, :re_record_interval => 28.days}
  c.configure_rspec_metadata!
end
