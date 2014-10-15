module Triannon
  class AnnotationLdpMapper

    # TODO might need to pass in url somehow, or create as blank node?
    def self.ldp_to_oa ldp_anno
      mapper = Triannon::AnnotationLdpMapper.new ldp_anno
      mapper.extract_base
      mapper.extract_body
      mapper.extract_target
      mapper.oa_graph
    end

    attr_accessor :id, :oa_graph

    def initialize ldp_anno
      @ldp = ldp_anno
      @oa_graph = RDF::Graph.new
      @root_uri = RDF::URI.new "http://changeme.com" # TODO read from Triannon::Config.base_uri
    end

=begin
<http://localhost:8080/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb> a <http://www.w3.org/ns/oa#Annotation>,
     <http://purl.org/dc/elements/1.1/describable>;
   <http://www.w3.org/ns/oa#hasBody> <http://localhost:8080/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23>;
   <http://www.w3.org/ns/oa#hasTarget> <http://localhost:8080/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1>;
   <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#commenting> .
=end
    def extract_base
      @ldp.graph.each_statement do |stmnt|
        if stmnt.predicate == RDF.type && stmnt.object == RDF::OpenAnnotation.Annotation
          @id = stmnt.subject.to_s.split('/').last
          @root_uri.join @id
          @oa_graph << [@root_uri, RDF.type, RDF::OpenAnnotation]
        elsif stmnt.predicate == RDF::OpenAnnotation.motivatedBy
          @oa_graph << [@root_uri, stmnt.predicate, stmnt.object]
        end
      end
    end

=begin
<http://localhost:8080/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> a <http://purl.org/dc/dcmitype/Text>,
     <http://www.w3.org/2011/content#ContentAsText>,
     <http://purl.org/dc/elements/1.1/describable>;
   <http://www.w3.org/2011/content#chars> "I love this!" .
=end
    def extract_body

    end

=begin
<http://localhost:8080/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1> a <http://purl.org/dc/dcmitype/Text>,
     <http://purl.org/dc/elements/1.1/describable>;
   <http://purl.org/dc/elements/1.1/format> "text/html";
   <http://triannon.stanford.edu/ns/externalReference> <http://purl.stanford.edu/kq131cs7229> .
=end
    def extract_target

    end

  end

end