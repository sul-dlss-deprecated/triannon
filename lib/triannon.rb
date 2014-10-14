require 'linkeddata'
require 'rdf/open_annotation'
require 'rdf/ldp'
require 'rdf/fcrepo4'
require 'bootstrap-sass'
require 'faraday'

module Triannon
  require "triannon/engine"

  class << self
    attr_accessor :ldp_config
  end

  def self.ldp_file
    "#{::Rails.root.to_s}/config/ldp.yml"
  end

  def self.ldp_config
    @ldp_config ||= begin
        raise "The #{::Rails.env} environment settings were not found in the ldp.yml config" unless ldp_yml[::Rails.env]
        ldp_yml[::Rails.env].symbolize_keys
      end
  end

  def self.ldp_yml
    require 'erb'
    require 'yaml'

    return @ldp_yml if @ldp_yml
    unless File.exists?(ldp_file)
      raise "You are missing the ldp configuration file: #{ldp_file}."
    end

    begin
      @ldp_yml = YAML::load_file(ldp_file)
    rescue => e
      raise("ldp.yml was found, but could not be parsed.\n")
    end

    if @ldp_yml.nil? || !@ldp_yml.is_a?(Hash)
      raise("ldp.yml was found, but was blank or malformed.\n")
    end

    return @ldp_yml
  end



end
