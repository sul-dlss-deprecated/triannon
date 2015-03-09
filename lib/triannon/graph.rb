module Triannon
  # a wrapper class for RDF::Graph that adds methods specific to Triannon
  # this is intended to be used for an RDF::Graph of a single annotation
  class Graph
    
# Class Methods ----------------------------------------------------------------

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
      q << [:s, RDF.type, RDF::OpenAnnotation.Annotation]
    end
    
    
# Instance Methods ----------------------------------------------------------------

    # instantiate this class for an RDF::Graph of a single annotation
    def initialize(rdf_graph)
      @graph = rdf_graph
    end
    
    # @return json-ld representation of graph with OpenAnnotation context as a url
    def jsonld_oa
      inline_context = @graph.dump(:jsonld, :context => Triannon::JsonldContext::OA_DATED_CONTEXT_URL)
      hash_from_json = JSON.parse(inline_context)
      hash_from_json["@context"] = Triannon::JsonldContext::OA_DATED_CONTEXT_URL
      hash_from_json.to_json
    end
    
    # @return json-ld representation of graph with IIIF context as a url
    def jsonld_iiif
      inline_context = @graph.dump(:jsonld, :context => Triannon::JsonldContext::IIIF_CONTEXT_URL)
      hash_from_json = JSON.parse(inline_context)
      hash_from_json["@context"] = Triannon::JsonldContext::IIIF_CONTEXT_URL
      hash_from_json.to_json
    end

    # DO NOT CALL before anno is stored.
    # The graph should have an assigned url for the @id of the root;  it shouldn't be a blank node
    # @return [Hash] a hash to be written to Solr, populated appropriately
    def solr_hash
      doc_hash = {}
      triannon_id = id_as_url
      if triannon_id
        # chars in Solr/Lucene query syntax are a big pain in Solr id fields, so we only use
        # the uuid portion of the Triannon anno id, not the full url
        solr_id = triannon_id.sub(Triannon.config[:triannon_base_url], "")
        doc_hash[:id] = solr_id.sub(/^\//, "") # remove first char slash if it is there

        # use short strings for motivation field
        doc_hash[:motivation] = motivated_by.map { |m| m.sub(RDF::OpenAnnotation.to_s, "") }

        # date field format: 1995-12-31T23:59:59Z; or w fractional seconds: 1995-12-31T23:59:59.999Z
        if annotated_at
          begin
            dt = Time.parse(annotated_at)
            doc_hash[:annotated_at] = dt.iso8601 if dt
          rescue ArgumentError
            # ignore invalid datestamps
          end
        end
        #doc_hash[:annotated_by_stem] # not yet implemented

        doc_hash[:target_url] = predicate_urls RDF::OpenAnnotation.hasTarget
        # TODO: recognize more target types
        doc_hash[:target_type] = ['external_URI'] if doc_hash[:target_url].size > 0

        doc_hash[:body_url] = predicate_urls RDF::OpenAnnotation.hasBody
        doc_hash[:body_type] = []
        doc_hash[:body_type] << 'external_URI' if doc_hash[:body_url].size > 0
        doc_hash[:body_chars_exact] = body_chars.map {|bc| bc.strip}
        doc_hash[:body_type] << 'content_as_text' if doc_hash[:body_chars_exact].size > 0
        doc_hash[:body_type] << 'no_body' if doc_hash[:body_type].size == 0

        doc_hash[:anno_jsonld] = jsonld_oa
      end
      doc_hash
    end
    

    # Canned Query methods ----------------------------------------------------------------
  
    # @return [String] the id of this annotation as a url string
    def id_as_url
      solution = @graph.query self.class.anno_query
      if solution && solution.size == 1
        solution.first.s.to_s
      # TODO:  raise exception if not a URI or missing?
      end
    end

    # @return [Array<String>] Array of urls expressing the OA motivated_by values
    def motivated_by
      motivations = []
      q = self.class.anno_query.dup
      q << [:s, RDF::OpenAnnotation.motivatedBy, :motivated_by]
      solution = @graph.query q
      if solution && solution.size > 0
        solution.each {|res|
          motivations << res.motivated_by.to_s
        }
      end
      # TODO:  raise exception if none? (validation)
      motivations
    end

    # @param [RDF::URI] predicate either RDF::OpenAnnotation.hasTarget or RDF::OpenAnnotation.hasBody
    # @return [Array<String>] urls for the predicate, as an Array of Strings
    def predicate_urls(predicate)
      urls = []
      predicate_solns = @graph.query [nil, predicate, nil]
      predicate_solns.each { |predicate_stmt |
        predicate_obj = predicate_stmt.object
        urls << predicate_obj.to_str.strip if predicate_obj.is_a?(RDF::URI)
      }
      urls
    end
    
    # For all bodies that are of type ContentAsText, get the characters as a single String in the returned Array.
    # @return [Array<String>] body chars as Strings, in an Array (one element for each contentAsText body)
    def body_chars
      result = []
      q = RDF::Query.new
      q << [nil, RDF::OpenAnnotation.hasBody, :body]
      q << [:body, RDF.type, RDF::Content.ContentAsText]
      q << [:body, RDF::Content.chars, :body_chars]
      solns = @graph.query q
      solns.each { |soln| 
        result << soln.body_chars.value
      }
      result
    end
    
    # @return [String] The datetime from the annotatedAt property, or nil
    def annotated_at
      solution = @graph.query [nil, RDF::OpenAnnotation.annotatedAt, nil]
      if solution && solution.size == 1
        solution.first.object.to_s
      end
    end


    # Changing the Graph ----------------------------------------------------------------

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
      anno_rdf_obj = anno_stmts.first.subject
      if anno_rdf_obj.is_a?(RDF::Node)
        # use null relative URI representation of blank node
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