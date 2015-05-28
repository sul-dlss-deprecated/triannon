require 'spec_helper'

describe Triannon::LdpToOaMapper, :vcr do
  let(:uber_container_url) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"}
  let(:root_container) {'specs'}
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:base_container_id) {"67/c0/18/9d/67c0189d-56d4-47fb-abea-1f995187b358"}
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:target_stmts) { RDF::Graph.new.from_ttl(target_ttl).statements }
  let(:target_container_id) {"#{base_container_id}/t/0a/b5/36/9d/0ab5369d-f872-4488-8f1e-3143819b94bf"}
  let(:stored_target_obj_url) {"#{uber_container_url}/#{root_container}/#{target_container_id}"}
  let(:ldp_anno) {
    a = Triannon::AnnotationLdp.new
    a.load_statements_into_graph base_stmts
    a
  }

  describe '#map_specific_resource' do
    it "simple source" do
      # see text position selector test
    end
    it "source with add'l properties" do
      # see fragment selector test
    end
    it "TextPositionSelector" do
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "http://purl.stanford.edu/kq131cs7229.html"
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
	      @prefix oa: <http://www.w3.org/ns/oa#> .
	      @prefix triannon: <http://triannon.stanford.edu/ns/> .
	      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

	      <#{stored_target_obj_url}> a oa:SpecificResource;
	         oa:hasSelector <#{stored_selector_obj_url}>;
	         oa:hasSource <#{stored_source_obj_url}> .

	      <#{stored_source_obj_url}> triannon:externalReference <#{source_url}> .

	      <#{stored_selector_obj_url}> a oa:TextPositionSelector;
	         oa:start \"0\"^^xsd:nonNegativeInteger;
	         oa:end \"66\"^^xsd:nonNegativeInteger .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      mapper.map_specific_resource(target_uri, RDF::Vocab::OA.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasTarget, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]
      source_obj = RDF::URI.new(source_url)
      expect(blank_node_solns).to include [blank_node, RDF::Vocab::OA.hasSource, source_obj]

      # source obj should only be in the mapped response for addl metadata assoc with the URI
      source_obj_subject_solns = mapper.oa_graph.query [source_obj, nil, nil]
      expect(source_obj_subject_solns.count).to eq 0

      # selector object
      selector_solns = mapper.oa_graph.query [blank_node, RDF::Vocab::OA.hasSelector, nil]
      expect(selector_solns.count).to eq 1
      selector_blank_node = selector_solns.first.object
      selector_obj_subject_solns = mapper.oa_graph.query [selector_blank_node, nil, nil]
      expect(selector_obj_subject_solns.count).to eq 3
      expect(selector_obj_subject_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextPositionSelector]
      start_obj_solns = mapper.oa_graph.query [selector_blank_node, RDF::Vocab::OA.start, nil]
      expect(start_obj_solns.count).to eq 1
      start_obj = start_obj_solns.first.object
      expect(start_obj.to_s).to eql "0"
      expect(start_obj.datatype).to eql RDF::XSD.nonNegativeInteger
      end_obj_solns = mapper.oa_graph.query [selector_blank_node, RDF::Vocab::OA.end, nil]
      expect(end_obj_solns.count).to eq 1
      end_obj = end_obj_solns.first.object
      expect(end_obj.to_s).to eql "66"
      expect(end_obj.datatype).to eql RDF::XSD.nonNegativeInteger

      # should get no triples with stored selector or source object urls
      expect(mapper.oa_graph.query([RDF::URI.new(stored_source_obj_url), nil, nil]).size).to eql 0
      expect(mapper.oa_graph.query([RDF::URI.new(stored_selector_obj_url), nil, nil]).size).to eql 0
    end
    it "TextQuoteSelector" do
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "http://purl.stanford.edu/kq131cs7229.html"
      suffix = " and The Canonical Epistles,"
      exact = "third and fourth Gospels"
      prefix = "manuscript which comprised the "
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
	      @prefix oa: <http://www.w3.org/ns/oa#> .
	      @prefix triannon: <http://triannon.stanford.edu/ns/> .

	      <#{stored_target_obj_url}> a oa:SpecificResource;
	         oa:hasSelector <#{stored_selector_obj_url}>;
	         oa:hasSource <#{stored_source_obj_url}> .

	      <#{stored_source_obj_url}> triannon:externalReference <#{source_url}> .

	      <#{stored_selector_obj_url}> a oa:TextQuoteSelector;
	         oa:suffix \"#{suffix}\";
	         oa:exact \"#{exact}\";
	         oa:prefix \"#{prefix}\" .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      mapper.map_specific_resource(target_uri, RDF::Vocab::OA.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasTarget, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]
      source_obj = RDF::URI.new(source_url)
      expect(blank_node_solns).to include [blank_node, RDF::Vocab::OA.hasSource, source_obj]

      # source obj should only be in the mapped response for addl metadata assoc with the URI
      source_obj_subject_solns = mapper.oa_graph.query [source_obj, nil, nil]
      expect(source_obj_subject_solns.count).to eq 0

      # selector object
      selector_solns = mapper.oa_graph.query [blank_node, RDF::Vocab::OA.hasSelector, nil]
      expect(selector_solns.count).to eq 1
      selector_blank_node = selector_solns.first.object
      selector_obj_subject_solns = mapper.oa_graph.query [selector_blank_node, nil, nil]
      expect(selector_obj_subject_solns.count).to eq 4
      expect(selector_obj_subject_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextQuoteSelector]
      expect(selector_obj_subject_solns).to include [selector_blank_node, RDF::Vocab::OA.suffix, suffix]
      expect(selector_obj_subject_solns).to include [selector_blank_node, RDF::Vocab::OA.exact, exact]
      expect(selector_obj_subject_solns).to include [selector_blank_node, RDF::Vocab::OA.prefix, prefix]

      # should get no triples with stored selector or source object urls
      expect(mapper.oa_graph.query([RDF::URI.new(stored_source_obj_url), nil, nil]).size).to eql 0
      expect(mapper.oa_graph.query([RDF::URI.new(stored_selector_obj_url), nil, nil]).size).to eql 0
    end
    it "FragmentSelector" do
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
      conforms_to_url = "http://www.w3.org/TR/media-frags/"
      frag_value = "xywh=0,0,200,200"
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
	      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
	      @prefix dcterms: <http://purl.org/dc/terms/> .
	      @prefix oa: <http://www.w3.org/ns/oa#> .
	      @prefix triannon: <http://triannon.stanford.edu/ns/> .
	      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

	      <#{stored_target_obj_url}> a oa:SpecificResource;
	         oa:hasSelector <#{stored_selector_obj_url}>;
	         oa:hasSource <#{stored_source_obj_url}> .

	      <#{stored_source_obj_url}> a dcmitype:Image;
	         triannon:externalReference <#{source_url}> .

	      <#{stored_selector_obj_url}> a oa:FragmentSelector;
	         rdf:value \"#{frag_value}\";
	         dcterms:conformsTo <#{conforms_to_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      mapper.map_specific_resource(target_uri, RDF::Vocab::OA.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasTarget, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]
      source_obj = RDF::URI.new(source_url)
      expect(blank_node_solns).to include [blank_node, RDF::Vocab::OA.hasSource, source_obj]

      # source obj should only be in the mapped response for addl metadata assoc with the URI
      source_obj_subject_solns = mapper.oa_graph.query [source_obj, nil, nil]
      expect(source_obj_subject_solns.count).to eq 1
      expect(source_obj_subject_solns).to include [source_obj, RDF.type, RDF::Vocab::DCMIType.Image]

      # selector object
      selector_solns = mapper.oa_graph.query [blank_node, RDF::Vocab::OA.hasSelector, nil]
      expect(selector_solns.count).to eq 1
      selector_blank_node = selector_solns.first.object
      selector_obj_subject_solns = mapper.oa_graph.query [selector_blank_node, nil, nil]
      expect(selector_obj_subject_solns.count).to eq 3
      expect(selector_obj_subject_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.FragmentSelector]
      expect(selector_obj_subject_solns).to include [selector_blank_node, RDF.value, frag_value]
      expect(selector_obj_subject_solns).to include [selector_blank_node, RDF::DC.conformsTo, conforms_to_url]

      # should get no triples with stored selector or source object urls
      expect(mapper.oa_graph.query([RDF::URI.new(stored_source_obj_url), nil, nil]).size).to eql 0
      expect(mapper.oa_graph.query([RDF::URI.new(stored_selector_obj_url), nil, nil]).size).to eql 0
    end
    #it "DataPositionSelector" do
    #  skip 'DataPositionSelector not yet implemented'
    #end
    #it "SvgSelector" do
    #  skip 'SvgSelector not yet implemented'
    #end
    it "returns true if it adds statements to oa_graph" do
      target_container_stmts =  RDF::Turtle::Reader.new("
	      @prefix oa: <http://www.w3.org/ns/oa#> .
	      @prefix triannon: <http://triannon.stanford.edu/ns/> .

	      <#{stored_target_obj_url}> a oa:SpecificResource;
	         oa:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
	         oa:hasSource <#{stored_target_obj_url}#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_specific_resource(target_uri, RDF::Vocab::OA.hasTarget)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_specific_resource(target_uri, RDF::Vocab::OA.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if the object doesn't have type SpecificResource" do
      # see 'returns false if it doesn't change oa_graph'
    end
  end #map_specific_resource

end
