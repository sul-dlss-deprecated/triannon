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

require 'simplecov'
require 'coveralls'
SimpleCov.profiles.define 'triannon' do
  add_filter '/spec/'
  add_group 'Config', 'config'
  add_group 'Libraries', 'lib'
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Helpers', 'app/helpers'
  add_group 'Services', 'app/services'
  add_group 'Views', 'app/views'
end
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start 'triannon'

require 'engine_cart'
EngineCart.load_application!

require 'triannon'
require 'auth_helper'  # include AuthHelpers

require 'rspec/rails'
require 'capybara/rails'
require 'capybara/rspec'

require 'pry'
require 'pry-doc'

RSpec.configure do |config|
  # include the authentication / authorization helpers in
  # any 'describe' blocks tagged with 'help: :auth'
  config.include AuthHelpers, :help => :auth

  # The settings below are suggested to provide a good initial experience
  # with RSpec, but feel free to customize to your heart's content.

  # Print the slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 5

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  # config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  # config.mock_with :rspec do |mocks|
  #   # Prevents you from mocking or stubbing a method that does not exist on
  #   # a real object. This is generally recommended.
  #   mocks.verify_partial_doubles = true
  # end
end

module Triannon
  def self.fixture_path path
    File.expand_path(File.dirname(__FILE__) + "/fixtures/#{path}")
  end
  def self.annotation_fixture fixture
    File.read Triannon.fixture_path("annotations/#{fixture}")
  end
end

# cache jsonld context documents
require 'restclient/components'
require 'rack/cache'
RestClient.enable Rack::Cache,
  metastore: "file:#{Rails.root}/tmp/rack-cache/meta",
  entitystore: "file:#{Rails.root}/tmp/rack-cache/body",
  default_ttl:  86400, # when to recheck, in seconds (daily = 60 x 60 x 24)
  verbose: false

require 'vcr'
VCR.configure do |c|
  # use rest client caching for jsonld context docs
  contexts = [
    OA::Graph::OA_DATED_CONTEXT_URL,
    OA::Graph::OA_CONTEXT_URL,
    OA::Graph::IIIF_CONTEXT_URL
  ]
  c.ignore_request {|r| contexts.include? r.uri }
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
  c.default_cassette_options = {:record => :new_episodes, :re_record_interval => 28.days}
  c.configure_rspec_metadata!
end

# @return [String] Solr url from config
def spec_solr_url
  @solr_url ||= begin
    Triannon.config[:solr_url].strip
  end
end

# @return [String] sanitized ldp url from config
def spec_ldp_url
  @ldp_url ||= begin
    ldp_url = Triannon.config[:ldp]['url'].strip
    ldp_url.chop! if ldp_url.end_with?('/')
    ldp_url
  end
end

# @return [String] sanitized uber container from config
def spec_uber_cont
  @uber_cont ||= begin
    uber_cont = Triannon.config[:ldp]['uber_container'].strip
    uber_cont = uber_cont[1..-1] if uber_cont.start_with?('/')
    uber_cont.chop! if uber_cont.end_with?('/')
    uber_cont
  end
end

# @return [String] sanitized triannon base url from config
def triannon_base_url
  @base_url ||= begin
    base_url = Triannon.config[:triannon_base_url].strip
    base_url = base_url[1..-1] if base_url.start_with?('/')
    base_url.chop! if base_url.end_with?('/')
    base_url
  end
end

# create root container(s) needed for testing, using a partiular VCR cassette
# @param [String] root_container - container to be created as child of uber container
# @param [String] vcr_cassette_name - the name for the vcr cassette that will capture these network transactions
def create_root_container(root_container, vcr_cassette_name)
  VCR.insert_cassette(vcr_cassette_name)
  begin
    Triannon::LdpWriter.create_basic_container(nil, spec_uber_cont)
    Triannon::LdpWriter.create_basic_container(spec_uber_cont, root_container)
  rescue Faraday::ConnectionFailed
    # probably here due to vcr cassette
  end
  VCR.eject_cassette(vcr_cassette_name)
end

# delete test objects from LDP storage and Solr, using a particular VCR cassette
# @param [Array<String>] ldp_containers - LDP container ids that will be deleted from test LDP storage
# @param [Array<String>] solr_ids - Solr doc ids that will be deleted from test Solr
# @param [String] root_container - container to be created as child of uber container
# @param [String] vcr_cassette_name - the name for the vcr cassette that will capture these network transactions
def delete_test_objects(ldp_containers, solr_ids, root_container, vcr_cassette_name)
  VCR.insert_cassette(vcr_cassette_name)
  ldp_containers.uniq.each { |cont_url|
    begin
      if Triannon::LdpWriter.container_exist?(cont_url.split("#{spec_ldp_url}/").last)
        Triannon::LdpWriter.delete_container cont_url
        Faraday.new(url: "#{cont_url}/fcr:tombstone").delete
      end
    rescue Triannon::LDPStorageError
      # probably here due to parent container being deleted first
    rescue Faraday::ConnectionFailed
      # probably here due to vcr cassette
    end
  }

  rsolr_client = RSolr.connect :url => spec_solr_url
  solr_ids.each { |solr_doc_id|
    rsolr_client.delete_by_id("#{root_container}/#{solr_doc_id}")
  }
  rsolr_client.commit
  VCR.eject_cassette(vcr_cassette_name)
end

