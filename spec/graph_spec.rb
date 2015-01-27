require 'spec_helper'

describe Triannon::Graph do
  
  context '#remove_non_base_statements' do
    it 'calls #remove_has_target_statements' do
      g = Triannon::Graph.new(RDF::Graph.new)
      expect(g).to receive(:remove_has_target_statements)
      allow(g).to receive(:remove_has_body_statements)
      g.remove_non_base_statements
    end
    it 'calls #remove_has_body_statements' do
      g = Triannon::Graph.new(RDF::Graph.new)
      expect(g).to receive(:remove_has_body_statements)
      allow(g).to receive(:remove_has_target_statements).and_return(g)
      g.remove_non_base_statements
    end
  end
  
  context '#remove_has_body_statements' do
    it 'calls remove_predicate_and_its_object_statements with RDF::OpenAnnotation.hasBody' do
      g = Triannon::Graph.new(RDF::Graph.new)
      expect(g).to receive(:remove_predicate_and_its_object_statements).with(RDF::OpenAnnotation.hasBody)
      g.remove_has_body_statements
    end
  end

  context '#remove_has_target_statements' do
    it 'calls remove_predicate_and_its_object_statements with RDF::OpenAnnotation.hasTarget' do
      g = Triannon::Graph.new(RDF::Graph.new)
      expect(g).to receive(:remove_predicate_and_its_object_statements).with(RDF::OpenAnnotation.hasTarget)
      g.remove_has_target_statements
    end
  end
  
  context '#remove_predicate_and_its_object_statements' do
    it 'calls *subject_statements for each object of predicate statement' do
      g = Triannon::Graph.new(RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": [
          "http://target.one.org",
          "http://target.two.org"
        ]
      }'))
      expect(Triannon::Graph).to receive(:subject_statements).with(RDF::URI.new("http://target.one.org"), anything)
      expect(Triannon::Graph).to receive(:subject_statements).with(RDF::URI.new("http://target.two.org"), anything)
      g.remove_predicate_and_its_object_statements(RDF::OpenAnnotation.hasTarget)
    end
    it 'removes each predicate statement' do
      g = Triannon::Graph.new(RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "motivatedBy": "oa:commenting",
        "hasTarget": [
          "http://target.one.org",
          {
            "@id": "http://dbpedia.org/resource/Love", 
            "@type": "oa:SemanticTag"
          }
        ]
      }'))
      pred_stmts = g.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      
      pred_stmts.each { |s| 
        expect_any_instance_of(RDF::Graph).to receive(:delete).with(s)
      }
      allow(Triannon::Graph).to receive(:subject_statements).and_return([])
      g.remove_predicate_and_its_object_statements(RDF::OpenAnnotation.hasTarget)
    end
    it "removes each statement about the predicate statement's object" do
      g = Triannon::Graph.new(RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "motivatedBy": "oa:commenting",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSelector": {
            "@type": "oa:FragmentSelector",
            "value": "xywh=0,0,200,200",
            "conformsTo": "http://www.w3.org/TR/media-frags/"
          }
        }
      }'))
      expect(g.size).to eql 8
      pred_stmts = g.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      pred_obj = pred_stmts.first.object
      sub_stmts = Triannon::Graph.subject_statements(pred_obj, g)
      expect(sub_stmts.size).to eql 5
      sub_stmts.each { |s|  
        expect_any_instance_of(RDF::Graph).to receive(:delete).with(s).and_call_original
      }
      allow_any_instance_of(RDF::Graph).to receive(:delete).with(pred_stmts.first).and_call_original
      g.remove_predicate_and_its_object_statements(RDF::OpenAnnotation.hasTarget)
      expect(g.size).to eql 2
    end
  end
  
  context '#make_null_relative_uri_out_of_blank_node' do
    it 'outer blank node becomes null relative uri' do
      g = RDF::Graph.new.from_ttl('[ 
      a <http://www.w3.org/ns/oa#Annotation>;
      <http://www.w3.org/ns/oa#hasBody> [
        a <http://www.w3.org/2011/content#ContentAsText>,
          <http://purl.org/dc/dcmitype/Text>;
        <http://www.w3.org/2011/content#chars> "I love this!"
        ]
      ] .')
      orig_size = g.size
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      expect(anno_stmts.size).to eql 1
      anno_rdf_obj = anno_stmts.first.subject
      expect(anno_rdf_obj).to be_a(RDF::Node)
      g = Triannon::Graph.new(g)
      g.make_null_relative_uri_out_of_blank_node
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      expect(anno_stmts.size).to eql 1
      anno_rdf_obj = anno_stmts.first.subject
      expect(anno_rdf_obj).to be_a(RDF::URI)
      expect(g.size).to eql orig_size
    end
    it 'null relative uri is left alone' do
      g = RDF::Graph.new.from_ttl('<> a <http://www.w3.org/ns/oa#Annotation>;
      <http://www.w3.org/ns/oa#hasBody> [
        a <http://www.w3.org/2011/content#ContentAsText>,
          <http://purl.org/dc/dcmitype/Text>;
        <http://www.w3.org/2011/content#chars> "I love this!"
        ] .')
      orig_size = g.size
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      expect(anno_stmts.size).to eql 1
      anno_rdf_obj = anno_stmts.first.subject
      expect(anno_rdf_obj).to be_a(RDF::URI)
      g = Triannon::Graph.new(g)
      g.make_null_relative_uri_out_of_blank_node
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      expect(anno_stmts.size).to eql 1
      anno_rdf_obj = anno_stmts.first.subject
      expect(anno_rdf_obj).to be_a(RDF::URI)
      expect(g.size).to eql orig_size
    end
  end
  
  context '*subject_statements' do
    it 'returns appropriate blank node statements when the subject is an RDF::Node in the graph' do
      graph = RDF::Graph.new.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasBody> [
           a <http://www.w3.org/2011/content#ContentAsText>,
             <http://purl.org/dc/dcmitype/Text>;
           <http://www.w3.org/2011/content#chars> "I love this!"
         ] .')
      body_resource = graph.query([nil, RDF::OpenAnnotation.hasBody, nil]).first.object
      body_stmts = Triannon::Graph.subject_statements(body_resource, graph)
      expect(body_stmts.size).to eql 3
      expect(body_stmts).to include([body_resource, RDF::Content::chars, "I love this!"])
      expect(body_stmts).to include([body_resource, RDF.type, RDF::Content.ContentAsText])
      expect(body_stmts).to include([body_resource, RDF.type, RDF::DCMIType.Text])
    end
    it 'recurses to get triples from objects of the subject statements' do
      graph = RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSource": "http://purl.stanford.edu/kq131cs7229.html",
          "hasSelector": {
            "@type": "oa:TextPositionSelector",
            "start": 0,
            "end": 66
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::Graph.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 6
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, "http://purl.stanford.edu/kq131cs7229.html"])
      selector_resource =  graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource])
      expect(target_stmts).to include([selector_resource, RDF.type, RDF::OpenAnnotation.TextPositionSelector])
      expect(target_stmts).to include([selector_resource, RDF::OpenAnnotation.start, RDF::Literal.new(0)])
      expect(target_stmts).to include([selector_resource, RDF::OpenAnnotation.end, RDF::Literal.new(66)])

      graph = RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSelector": {
            "@type": "oa:FragmentSelector",
            "value": "xywh=0,0,200,200",
            "conformsTo": "http://www.w3.org/TR/media-frags/"
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::Graph.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 5
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      selector_resource =  graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource])
      expect(target_stmts).to include([selector_resource, RDF.type, RDF::OpenAnnotation.FragmentSelector])
      expect(target_stmts).to include([selector_resource, RDF.value, RDF::Literal.new("xywh=0,0,200,200")])
      expect(target_stmts).to include([selector_resource, RDF::DC.conformsTo, "http://www.w3.org/TR/media-frags/"])
    end
    it 'finds all properties of URI nodes' do
      graph = RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSource": {
            "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg",
            "@type": "dctypes:Image"
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::Graph.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 3
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"])
      source_resource = graph.query([target_resource, RDF::OpenAnnotation.hasSource, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, source_resource])
      expect(target_stmts).to include([source_resource, RDF.type, RDF::DCMIType.Image])
    end
    it 'empty Array when the subject is not in the graph' do
      graph = RDF::Graph.new.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasBody> [
           a <http://www.w3.org/2011/content#ContentAsText>,
             <http://purl.org/dc/dcmitype/Text>;
           <http://www.w3.org/2011/content#chars> "I love this!"
         ] .')
      expect(Triannon::Graph.subject_statements(RDF::Node.new, graph)).to eql []
      expect(Triannon::Graph.subject_statements(RDF::URI.new("http://not.there.org"), graph)).to eql []
    end
    it 'empty Array when the subject is an RDF::URI with no additional properties' do
      graph = RDF::Graph.new.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>.')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      expect(target_resource).to be_a RDF::URI
      expect(Triannon::Graph.subject_statements(target_resource, graph)).to eql []
    end
    it 'empty Array when subject is not RDF::Node or RDF::URI' do
      graph = RDF::Graph.new.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>.')
      expect(Triannon::Graph.subject_statements(RDF.type, graph)).to eql []
    end
  end # *subject_statements

  context '*anno_query' do
    it "should find a solution when graph has RDF.type OA::Annotation" do
      my_url = "http://fakeurl.org/id"
      g = RDF::Graph.new.from_ttl("<#{my_url}> a <http://www.w3.org/ns/oa#Annotation> .")
      solutions = g.query Triannon::Graph.anno_query
      expect(solutions.size).to eq 1
      expect(solutions.first.s.to_s).to eq my_url
    end
    it "should not find a solution when graph has no RDF.type OA::Annotation" do
      g = RDF::Graph.new.from_ttl("<http://anywehre.com> a <http://foo.org/thing> .")
      solutions = g.query Triannon::Graph.anno_query
      expect(solutions.size).to eq 0
    end
    it "doesn't find solution when graph is empty" do
      solutions = RDF::Graph.new.query Triannon::Graph.anno_query
      expect(solutions.size).to eq 0
    end
  end

end