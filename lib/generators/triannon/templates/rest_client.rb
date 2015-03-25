require 'restclient/components'
require 'rack/cache'
RestClient.enable Rack::Cache,
  metastore: "file:#{Rails.root}/tmp/rack-cache/meta",
  entitystore: "file:#{Rails.root}/tmp/rack-cache/body"