require 'spec_helper'

describe Triannon::LdpToOaMapper, :vcr do
  let(:uber_container_url) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"}
  let(:root_container) {'specs'}
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:base_container_id) {"67/c0/18/9d/67c0189d-56d4-47fb-abea-1f995187b358"}
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:body_stmts) { RDF::Graph.new.from_ttl(body_ttl).statements }
  let(:body_container_id) {"#{base_container_id}/b/67/f2/30/a2/67f230a2-3bf3-41e5-952e-8362dc7a5366"}
  let(:stored_body_obj_url) {"#{uber_container_url}/#{root_container}/#{body_container_id}"}
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

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
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
    it "adds all relevant statements from simple de-skolemized blank node to @oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      mapper.map_content_as_text(body_uri, RDF::Vocab::OA.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasBody, nil]
      expect(solns.count).to eq 1
      blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
      expect(blank_node_solns).to include [blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
      expect(blank_node_solns).to include [blank_node, RDF::Vocab::CNT.chars, "ldp loader test"]
    end
    it "adds all relevant statements in de-skolemized blank node to @oa_graph" do
      body_container_stmts = RDF::Turtle::Reader.new("
        @prefix cnt: <http://www.w3.org/2011/content#> .
        @prefix dc11: <http://purl.org/dc/elements/1.1/> .
        @prefix dcmitype: <http://purl.org/dc/dcmitype/> .

        <#{stored_body_obj_url}> a 
             dcmitype:Text,
             cnt:ContentAsText;
           dc11:format \"text/plain\";
           dc11:language \"en\";
           cnt:chars \"I love this!\" .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
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

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_content_as_text(body_uri, RDF::Vocab::OA.hasBody)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_content_as_text(target_uri, RDF::Vocab::OA.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if the object doesn't have ContentAsText type" do
      # see 'returns false if it doesn't change oa_graph'
    end
    it "attaches external ref to passed param for subject" do
      ldp_anno.load_statements_into_graph body_stmts
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
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
