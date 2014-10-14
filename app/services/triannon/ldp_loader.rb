require 'faraday'

module Triannon

  class LdpLoader

    def self.load key
      l = Triannon::LdpLoader.new key
      l.load_annotation
      l.load_body
      l.load_target
    end

    attr_accessor :annotation

    def initialize key
      @key = key
      @base_uri = Triannon.ldp_config[:url]
      @annotation = Triannon::AnnotationLdp.new
    end

    def load_annotation
      @annotation.load_data_into_graph get_ttl @key
    end

    def load_body
      uri = @annotation.body_uri.to_s
      sub_path = uri.split(@base_uri + '/').last
      @annotation.load_data_into_graph get_ttl sub_path
    end

    def load_target
      uri = @annotation.target_uri.to_s
      sub_path = uri.split(@base_uri + '/').last
      @annotation.load_data_into_graph get_ttl sub_path
    end

    protected

    def get_ttl sub_path
      resp = conn.get do |req|
        req.url " #{sub_path}"
        req.headers['Accept'] = 'text/turtle'
      end
      resp.body
    end

    def conn
      @c ||= Faraday.new @base_uri
    end

  end


end
