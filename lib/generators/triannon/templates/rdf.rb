require 'rdf/util/file'
require 'faraday'
require 'faraday_middleware'

# configure RDF to cache via faraday-http-cache
RDF::Util::File.http_adapter = RDF::Util::File::FaradayAdapter
RDF::Util::File::FaradayAdapter.conn = Faraday.new do |builder|
  builder.use FaradayMiddleware::FollowRedirects
  builder.use :http_cache, store: Rails.cache, shared_cache: false, logger: Rails.logger, instrumenter: ActiveSupport::Notifications
  builder.adapter Faraday.default_adapter
end

