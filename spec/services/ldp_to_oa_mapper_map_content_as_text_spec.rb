require 'spec_helper'

describe Triannon::LdpToOaMapper, :vcr do
  let(:triannon_anno_container) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"}
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:base_container_id) {"f8/c2/36/de/f8c236de-be13-499d-a1e2-3f6fbd3a89ec"}
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:body_stmts) { RDF::Graph.new.from_ttl(body_ttl).statements }
  let(:body_container_id) {"#{base_container_id}/b/75/18/5b/af/75185baf-7057-4762-bfb2-432e88221810"}
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:target_stmts) { RDF::Graph.new.from_ttl(target_ttl).statements }
  let(:ldp_anno) {
    a = Triannon::AnnotationLdp.new
    a.load_statements_into_graph base_stmts
    a
  }

  describe '#map_content_as_text' do
    it "adds de-skolemized blank node with type ContentAsText to @oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasBody, nil]
      expect(solns.count).to eq 0

      mapper.map_content_as_text(body_uri, RDF::Vocab::OA.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasBody, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      expect(blank_node.class).to eq RDF::Node
      expect(mapper.oa_graph.query([blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eq 1
    end
    it "adds all relevant statements in simple skolemized blank node to @oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.map_content_as_text(body_uri, RDF::Vocab::OA.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasBody, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
      expect(blank_node_solns).to include [blank_node, RDF::Vocab::CNT.chars, "Solr integration test"]
    end
    it "adds all relevant statements in skolemized blank node to @oa_graph" do
      body_container_stmts = RDF::Turtle::Reader.new("
      @prefix content: <http://www.w3.org/2011/content#> .
      @prefix dc11: <http://purl.org/dc/elements/1.1/> .
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <http://localhost:8983/fedora/rest/anno/#{body_container_id}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           dcmitype:Text,
           content:ContentAsText;
         dc11:format \"text/plain\";
         dc11:language \"en\";
         content:chars \"I love this!\";
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <http://localhost:8983/fedora/rest/anno/#{body_container_id}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.map_content_as_text(body_uri, RDF::Vocab::OA.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasBody, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 5
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
      expect(blank_node_solns).to include [blank_node, RDF::DC11.format, "text/plain"]
      expect(blank_node_solns).to include [blank_node, RDF::DC11.language, "en"]
      expect(blank_node_solns).to include [blank_node, RDF::Vocab::CNT.chars, "I love this!"]
    end
    it "returns true if it adds statements to oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_content_as_text(body_uri, RDF::Vocab::OA.hasBody)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_content_as_text(target_uri, RDF::Vocab::OA.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if the object doesn't have ContentAsText type" do
      # see 'returns false if it doesn't change oa_graph'
    end
    it "attaches external ref to passed param for subject" do
      stored_body_obj_url = "#{triannon_anno_container}/#{body_container_id}"
      ldp_anno.load_statements_into_graph body_stmts
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      # map target to root statement
      mapper.map_external_ref(target_uri, RDF::Vocab::OA.hasTarget)
      orig_size = mapper.oa_graph.size
      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasTarget, nil]
      expect(solns.count).to eq 1
      target_obj = solns.first.object
      expect(mapper.oa_graph.query([target_obj, nil, nil]).size).to eq 0
      # map body to target object
      mapper.map_content_as_text(RDF::URI.new(stored_body_obj_url), RDF::Vocab::OA.hasBody, target_obj)

      solns = mapper.oa_graph.query [target_obj, nil, nil]
      expect(solns.count).to eq 1
      expect(mapper.oa_graph.query([target_obj, RDF::Vocab::OA.hasBody, nil]).size).to eql 1
      expect(mapper.oa_graph.size).to eql orig_size + 4
    end
  end #map_content_as_text

end
