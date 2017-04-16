
# Using rest-client with options to enable
# a client HTTP cache
require 'rest-client'
if ENV['RACK_CACHE_ENABLED'].to_s.upcase == 'TRUE'
    require 'dalli'
    require 'restclient/components'
    require 'rack/cache'
    RestClient.enable Rack::CommonLogger, STDOUT
    # Enable the HTTP cache to store meta and entity data according
    # to the env config values or the defaults given here. See
    # http://rtomayko.github.io/rack-cache/configuration for available options.
    metastore = ENV['RACK_CACHE_METASTORE'] || 'file:/tmp/cache/meta'
    entitystore = ENV['RACK_CACHE_ENTITYSTORE'] || 'file:/tmp/cache/body'
    verbose = ENV['RACK_CACHE_VERBOSE'].to_s.upcase == 'TRUE' || false
    RestClient.enable Rack::Cache,
        :metastore => metastore, :entitystore => entitystore, :verbose => verbose
    # Prime the HTTP cache with some common json-ld contexts used for
    # IIIF and open annotations.
    contexts = [
        'http://iiif.io/api/image/1/context.json',
        'http://iiif.io/api/image/2/context.json',
        'http://iiif.io/api/presentation/1/context.json',
        'http://iiif.io/api/presentation/2/context.json',
        'http://www.shared-canvas.org/ns/context.json'
    ]
    contexts.each {|c| RestClient.get c }
end

module Triannon
  class Engine < ::Rails::Engine
    isolate_namespace Triannon
  end
end
