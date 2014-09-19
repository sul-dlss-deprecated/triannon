module Cerberus::Annotations
  class Annotation < ActiveRecord::Base
    
    validates :data, presence: true,
                      length: {minimum: 30}

    def url
      json_ld['@id'] if json_ld
    end

    def type
      rdf.detect { |s| 
        s.predicate.to_s == RDF.type
      }.object.to_str
    end
    
    def has_target
      # FIXME:  can have multiple targets per spec  (example 8)
      # FIXME:  target might be more than a string (examples 14-17)
      stmt = rdf.find_all { |s| 
        s.predicate.to_s == RDF::OpenAnnotation.hasTarget
      }.first
      stmt.object.to_str if stmt
    end
    
    def has_body
      # FIXME:  can have multiple bodies per spec
      stmt = rdf.find_all { |s| 
        s.predicate.to_s == RDF::OpenAnnotation.hasBody
      }.first
      
      # FIXME:  body can be other things
      # if body is blank node and has character content, then return it
      body = stmt.object if stmt
      if body && body.is_a?(RDF::Node)
        body_stmts = rdf.find_all { |s| s.subject == body }
        if body_stmts && 
            body_stmts.detect { |s| 
              s.predicate.to_s == RDF.type &&
              s.object.to_s == RDF::Content.ContentAsText
            }
          chars_stmt = body_stmts.detect { |s| s.predicate.to_s == RDF::Content.chars}
          return chars_stmt.object.to_s if chars_stmt
        end
      end
      nil
    end

    def motivated_by
      # FIXME:  can have multiple motivations per spec  (examples 9, 10, 11)
      # http://www.openannotation.org/spec/core/core.html#Motivations
      s = rdf.find_all { |s| 
        s.predicate.to_s == RDF::OpenAnnotation.motivatedBy
      }.first
      s.object.to_str
    end

    def rdf
      @rdf ||= JSON::LD::API.toRdf(json_ld) if json_ld
    end

    def graph
      g = data_to_graph
      @graph ||= g if g
    end

    private

    # loads RDF::Graph from data attribute.  If data is in json-ld, converts it to turtle.
    def data_to_graph
      begin
        if data
          case data
            when /\{\s*\"@\w+\"/
              json ||= JSON.parse(data)
              g ||= RDF::Graph.new << JSON::LD::API.toRdf(json_ld) if json
              self.data = g.dump(:ttl) if g
            #when /http/
            #  g ||= RDF::Graph.load(data, :format => :ttl)
            else # assume turtle
              g = RDF::Graph.new
              g.from_ttl(data)
              g = nil if g.size == 0
          end
        end # if data
      rescue Exception => e
        g = nil
      end
      g
    end

    def json_ld
      @json_ld ||= JSON.parse(data) rescue nil
    end

  end
end
