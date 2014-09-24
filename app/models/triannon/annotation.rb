module Triannon
  class Annotation < ActiveRecord::Base
    
    validates :data, presence: true,
                      length: {minimum: 30}

    # full validation should be optional?
    #   minimal:  a subject with the right type and a hasTarget?  (see url)
    # and perhaps modeled on this:
    #   https://github.com/uq-eresearch/lorestore/blob/3e9aa1c69aafd3692c69aa39c64bfdc32b757892/src/main/resources/OAConstraintsSPARQL.json

    def url
      if graph_exists?
        solution = graph.query self.class.basic_query
        if solution && solution.size == 1
          solution.first.s.to_s
        # TODO:  raise exception if no URL?
        end
      end
    end
    
    # FIXME:  this should be part of validation:  RDF.type should be RDF::OpenAnnotation.Annotation
    def type
      if graph_exists?
        query = RDF::Query.new
        query << [:s, RDF::OpenAnnotation.hasTarget, nil]
        query << [:s, RDF.type, :type]
        solution = graph.query query
        if solution && solution.size == 1
          solution.first.type.to_s
        # TODO:  raise exception if no type?
        end
      end
    end
    
    def has_target
      # FIXME:  target might be more than a string (examples 14-17)
      if graph_exists?
        q = RDF::Query.new
        q << [:s, RDF.type, RDF::URI("http://www.w3.org/ns/oa#Annotation")]
        q << [:s, RDF::OpenAnnotation.hasTarget, :target]
        solution = graph.query q
        if solution && solution.size > 0
          targets = []
          solution.each {|res|
            targets << res.target.to_s
          }
          targets
        # TODO:  raise exception if none?
        end
      end
    end
    
    def has_body
      # FIXME:  body can be other things besides blank node with chars
      bodies = []
      if graph_exists?
        q = self.class.basic_query.dup
        q << [:s, RDF::OpenAnnotation.hasBody, :body]
        # for chars content
        # the following two lines are equivalent in identifying inline chars content
        # q << [:body, RDF.type, RDF::Content.ContentAsText]
        q << [:body, RDF::Content.chars, :chars]
        # for non-chars content
        # // non-embedded Text resource
        #?body a dctypes:Text ;
        #  dc:format "application/msword .
        solution = graph.query q
        if solution && solution.size > 0
          solution.each {|res|
            bodies << res.chars.to_s
          }
        end
      end
      bodies
    end

    def motivated_by
      if graph_exists?
        q = self.class.basic_query.dup
        q << [:s, RDF::OpenAnnotation.motivatedBy, :motivated_by]
        solution = graph.query q
        if solution && solution.size > 0
          motivations = []
          solution.each {|res|
            motivations << res.motivated_by.to_s
          }
          motivations
        # TODO:  raise exception if none?
        end
      end
    end

    def rdf
      @rdf ||= JSON::LD::API.toRdf(json_ld) if json_ld
    end

    def graph
      g = data_to_graph
      @graph ||= g if g
    end

    # query for a subject with 
    #  predicate  RDF::OpenAnnotation.hasTarget  
    #  type of RDF::OpenAnnotation.Annotation
    def self.basic_query
      @basic_query ||= begin
        basic_query = RDF::Query.new
        basic_query << [:s, RDF.type, RDF::URI("http://www.w3.org/ns/oa#Annotation")]
        basic_query << [:s, RDF::OpenAnnotation.hasTarget, nil]
      end
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
    
    def graph_exists?
      graph && graph.size > 0
    end

  end
end
