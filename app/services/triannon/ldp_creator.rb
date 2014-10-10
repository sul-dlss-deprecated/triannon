require 'faraday'

module Triannon
  class LdpCreator

    def self.create(anno)
      res = Triannon::LdpCreator.new anno
      res.create
      res.create_body_container
      res.create_target_container
      res.create_body
      res.create_target
      res
    end

    attr_accessor :id

    def initialize(anno)
      @anno = anno
      @base_uri = 'http://localhost:8080/rest/anno'  # TODO use Triannon.ldp_config
    end

    def create
      motivation = @anno.motivated_by.first
      body  =<<-EOTL
        <> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#motivatedBy> <#{motivation}> .
      EOTL

      response = conn.post do |req|
        req.headers['Content-Type'] = 'text/turtle'
        req.body = body
      end

      @id = response.headers['Location'].split('/').last
    end

    def create_body_container
      body =<<-TTL
        @prefix ldp: <http://www.w3.org/ns/ldp#> .
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <> a ldp:DirectContainer;
           ldp:hasMemberRelation oa:hasBody;
           ldp:membershipResource <#{@base_uri}/#{id}> .
      TTL
      # TODO figure out base uri

      res = conn.post do |req|
        req.url "#{id}"
        req.headers['Content-Type'] = 'text/turtle'
        req.headers['Slug'] = 'b'
        req.body = body
      end
    end

    def create_target_container
      body =<<-TTL
        @prefix ldp: <http://www.w3.org/ns/ldp#> .
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <> a ldp:DirectContainer;
           ldp:hasMemberRelation oa:hasTarget;
           ldp:membershipResource <#{@base_uri}/#{id}> .
      TTL
      # TODO figure out base uri
      conn.post do |req|
        req.url "#{id}"
        req.headers['Content-Type'] = 'text/turtle'
        req.headers['Slug'] = 't'
        req.body = body
      end
    end

    def create_body
      body_chars = @anno.has_body.first        # TODO handle more than just one body or different types
      body =<<-TTL
        @prefix cnt: <http://www.w3.org/2011/content#> .
        @prefix dctypes: <http://purl.org/dc/dcmitype/> .

        <> a cnt:ContentAsText, dctypes:Text;
           cnt:chars '#{body_chars}' .
      TTL
      # TODO extract body from annotation

      response = conn.post do |req|
        req.url "#{@id}/b"
        req.headers['Content-Type'] = 'text/turtle'
        req.body = body
      end
      @body_id = response.headers['Location'].split('/').last
    end

    def create_target
      body =<<-TTL
        @prefix dc: <http://purl.org/dc/elements/1.1/> .
        @prefix dctypes: <http://purl.org/dc/dcmitype/> .
        @prefix triannon: <http://triannon.stanford.edu/ns/> .

        <> a dctypes:Text;
           dc:formant 'text/html';
           triannon:externalReference 'http://purl.stanford.edu/kq131cs7229' .
      TTL
      # TODO extract target from annotation

      response = conn.post do |req|
        req.url "#{@id}/t"
        req.headers['Content-Type'] = 'text/turtle'
        req.body = body
      end

      @target_id = response.headers['Location'].split('/').last
    end

    def conn
      @c ||= Faraday.new @base_uri
    end

  protected
    def create_container type
      # TODO Refactor common container code here
    end

  end
end
