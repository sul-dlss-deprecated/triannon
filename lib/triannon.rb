require 'linkeddata'
require 'rdf/open_annotation'
require 'rdf/iiif'
require 'rdf/ldp'
require 'rdf/fcrepo4'
require 'rdf/triannon_vocab'
require 'bootstrap-sass'
require 'faraday' # for writing to LDP store
require 'rsolr'
require 'retries' # for writing to Solr

module Triannon
  require "triannon/engine"
  require "triannon/error"
  require "triannon/graph"
  require "triannon/iiif_anno_list"
  require "triannon/jsonld_context"

  class << self
    attr_accessor :config
  end

  def self.triannon_file
    "#{::Rails.root.to_s}/config/triannon.yml"
  end

  def self.config
    @triannon_config ||= begin
        raise "The #{::Rails.env} environment settings were not found in the triannon.yml config" unless config_yml[::Rails.env]
        config_yml[::Rails.env].symbolize_keys
      end
  end

  def self.config_yml
    require 'erb'
    require 'yaml'

    return @triannon_yml if @triannon_yml
    unless File.exists?(triannon_file)
      raise "You are missing the triannon configuration file: #{triannon_file}."
    end

    begin
      @triannon_yml = YAML::load_file(triannon_file)
    rescue => e
      raise("triannon.yml was found, but could not be parsed.\n")
    end

    if @triannon_yml.nil? || !@triannon_yml.is_a?(Hash)
      raise("triannon.yml was found, but was blank or malformed.\n")
    end

    return @triannon_yml
  end



end
