module Cerberus::Annotations
  class Annotation < ActiveRecord::Base

    def url
      json['@id'] if json
    end

    def type
      rdf.detect { |s| 
        s.predicate.to_s == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
      }.object.to_str
    end
    
    def has_target
      # FIXME:  can have multiple targets per spec  (example 8)
      # FIXME:  target might be more than a string (examples 14-17)
      stmt = rdf.find_all { |s| 
        s.predicate.to_s == "http://www.w3.org/ns/oa#hasTarget"
      }.first
      stmt.object.to_str if stmt
    end
    
    def has_body
      # FIXME:  can have multiple bodies per spec
      stmt = rdf.find_all { |s| 
        s.predicate.to_s == "http://www.w3.org/ns/oa#hasBody"
      }.first
      
      # FIXME:  body can be other things
      # if body is blank node and has character content, then return it
      body = stmt.object if stmt
      if body && body.is_a?(RDF::Node)
        body_stmts = rdf.find_all { |s| s.subject == body }
        if body_stmts && 
            body_stmts.detect { |s| 
              s.predicate.to_s == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" &&
              s.object.to_s == "http://www.w3.org/2011/content#ContentAsText"
            }
          chars_stmt = body_stmts.detect { |s| s.predicate.to_s == "http://www.w3.org/2011/content#chars"}
          return chars_stmt.object.to_s if chars_stmt
        end
      end
      nil
    end

    def motivated_by
      # FIXME:  can have multiple motivations per spec  (examples 9, 10, 11)
      # http://www.openannotation.org/spec/core/core.html#Motivations
      s = rdf.find_all { |s| 
        s.predicate.to_s == "http://www.w3.org/ns/oa#motivatedBy"
      }.first
      s.object.to_str
    end

    def rdf
      @rdf ||= JSON::LD::API.toRdf(json) if json
    end

    def graph
      @graph ||= RDF::Graph.new << rdf if json
    end

    private

    def json
      @json ||= JSON.parse(data) rescue nil
    end

  end
end
