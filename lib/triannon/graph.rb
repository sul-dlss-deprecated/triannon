module Triannon
  # a wrapper class for RDF::Graph that adds methods specific to Triannon
  class Graph
    
    # given an RDF::Resource (an RDF::Node or RDF::URI), look for all the statements with that object
    #  as the subject, and recurse through the graph to find all descendant statements pertaining to the subject
    # @param subject the RDF object to be used as the subject in the graph query.  Should be an RDF::Node or RDF::URI
    # @param [RDF::Graph] graph
    # @return [Array[RDF::Statement]] all the triples with the given subject
    def self.subject_statements(subject, graph)
      result = []
      graph.query([subject, nil, nil]).each { |stmt|
        result << stmt
        subject_statements(stmt.object, graph).each { |s| result << s }
      }
      result.uniq
    end
    
    # @return [RDF::Query] query for a subject :s with type of RDF::OpenAnnotation.Annotation
    def self.anno_query
      q = RDF::Query.new
      q << [:s, RDF.type, RDF::URI("http://www.w3.org/ns/oa#Annotation")]
    end
    
    def initialize(rdf_graph)
      @graph = rdf_graph
    end
    
    # remove all RDF::OpenAnnotation.hasBody and .hasTarget statements
    #  and any other statements associated with body and target objects, 
    #  leaving all statements to be stored as part of base object in LDP store
    def remove_non_base_statements
      remove_has_target_statements
      remove_has_body_statements
    end
    
    # remove all RDF::OpenAnnotation.hasBody statements and any other statements associated with body objects
    def remove_has_body_statements
      remove_predicate_and_its_object_statements RDF::OpenAnnotation.hasBody
    end
    
    # remove all RDF::OpenAnnotation.hasTarget statements and any other statements associated with body objects
    def remove_has_target_statements
      remove_predicate_and_its_object_statements RDF::OpenAnnotation.hasTarget
    end
    
    # remove all such predicate statements and any other statements associated with predicates' objects
    def remove_predicate_and_its_object_statements(predicate)
      predicate_stmts = @graph.query([nil, predicate, nil])
      predicate_stmts.each { |pstmt|
        pred_obj = pstmt.object
        Triannon::Graph.subject_statements(pred_obj, @graph).each { |s|
          @graph.delete s
        } unless !Triannon::Graph.subject_statements(pred_obj, @graph)
        @graph.delete pstmt
      }
    end
    
    # transform an outer blank node into a null relative URI
    def make_null_relative_uri_out_of_blank_node
      anno_stmts = @graph.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      # FIXME: should actually look for subject with type of RDF::OpenAnnotation.Annotation
      anno_rdf_obj = anno_stmts.first.subject
      if anno_rdf_obj.is_a?(RDF::Node)
        # we need to use the null relative URI representation of blank nodes to write to LDP
        anno_subject = RDF::URI.new
      else # it's already a URI
        anno_subject = anno_rdf_obj
      end
      Triannon::Graph.subject_statements(anno_rdf_obj, @graph).each { |s|
        if s.subject == anno_rdf_obj && anno_subject != anno_rdf_obj
          @graph << RDF::Statement({:subject => anno_subject,
                               :predicate => s.predicate,
                               :object => s.object})
          @graph.delete s
        end
      }
    end
    
    # send unknown methods to RDF::Graph
    def method_missing(sym, *args, &block)
      @graph.send sym, *args, &block
    end
    
  end
end