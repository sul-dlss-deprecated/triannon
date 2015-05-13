require 'linkeddata'
require 'oa/graph'
require 'rdf/triannon_vocab'
require 'bootstrap-sass'
require 'faraday' # for writing to LDP store
require 'rsolr'
require 'retries' # for writing to Solr

module Triannon
  require 'triannon/engine'
  require 'triannon/error'
  require 'triannon/iiif_anno_list'
  require 'triannon/oa_graph_helper.rb'

  class << self
    attr_accessor :config
  end

  def self.triannon_file
    "#{::Rails.root}/config/triannon.yml"
  end

  def self.config
    @triannon_config ||= begin
        fail "The #{::Rails.env} environment settings were not found in the triannon.yml config" unless config_yml[::Rails.env]
        config_yml[::Rails.env].symbolize_keys
      end
  end

  def self.config_yml
    require 'erb'
    require 'yaml'

    return @triannon_yml if @triannon_yml
    fail "You are missing the triannon configuration file: #{triannon_file}." unless File.exist?(triannon_file)

    begin
      @triannon_yml = YAML.load_file(triannon_file)
    rescue
      raise 'triannon.yml was found, but could not be parsed.'
    end

    if @triannon_yml.nil? || !@triannon_yml.is_a?(Hash)
      fail 'triannon.yml was found, but was blank or malformed.'
    end

    @triannon_yml
  end

end
