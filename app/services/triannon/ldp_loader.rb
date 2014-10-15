
module Triannon

  # Loads an existing Annotation from the LDP server
  class LdpLoader

    def self.load key
      l = Triannon::LdpLoader.new key
      l.load_annotation
      l.load_body
      l.load_target

      oa_graph = AnnotationLdpMapper.ldp_to_oa l.annotation
      oa_graph
    end

    attr_accessor :annotation

    def initialize key
      @key = key
      @base_uri = Triannon.config[:ldp_url]
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
