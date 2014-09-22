module Cerberus::Annotations
  class Annotation < ActiveRecord::Base
    
    validates :data, presence: true,
                      length: {minimum: 30}

    # full validation should be optional?
    #   minimal:  a subject with the right type and a hasTarget?  (see url)
    # and perhaps modeled on this:
    #   https://github.com/uq-eresearch/lorestore/blob/3e9aa1c69aafd3692c69aa39c64bfdc32b757892/src/main/resources/OAConstraintsSPARQL.json

    def url
      if graph && graph.size > 0
        query = RDF::Query.new
        query << [:s, RDF.type, RDF::URI("http://www.w3.org/ns/oa#Annotation")]
        query << [:s, RDF::OpenAnnotation.hasTarget, nil]
        solution = graph.query(query)
        if solution && solution.size == 1
          solution.first.s.to_s
        # TODO:  raise exception if no URL?
        end
      end
    end
    
    # FIXME:  this should be part of validation:  RDF.type should be RDF::OpenAnnotation.Annotation
    def type
      # does this need to be the first non-blank node?
      # a subject with the right type and a hasTarget??
#      graph.query([url, RDF.type, nil]).first.object.to_s if graph
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
#      if graph && graph.size > 0
#        stmts = graph.query([nil, RDF::OpenAnnotation.motivatedBy, nil])
#        stmts.first.object.to_str if stmts && stmts.size > 0
#      end
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
      end
      g
    end

    def json_ld
      @json_ld ||= JSON.parse(data) rescue nil
    end

  end
end
