require 'linkeddata'
require 'rdf/open_annotation'
require 'bootstrap-sass'

module Cerberus
  module Annotations
    require "cerberus/annotations/engine"
    
    # Create and maintain a cache of downloaded URIs
    require 'open-uri/cached'
    URI_CACHE = File.expand_path(File.join(File.dirname(Rails.root.to_s), "uri-cache"))
    Dir.mkdir(URI_CACHE) unless File.directory?(URI_CACHE)
    OpenURI::Cache.class_eval { @cache_path = URI_CACHE }
  end
end
