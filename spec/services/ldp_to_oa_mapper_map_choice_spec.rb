require 'spec_helper'

describe Triannon::LdpToOaMapper, :vcr do
  let(:uber_container_url) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"}
  let(:root_container) {'specs'}
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:base_container_id) {"67/c0/18/9d/67c0189d-56d4-47fb-abea-1f995187b358"}
  let(:body_container_id) {"#{base_container_id}/b/67/f2/30/a2/67f230a2-3bf3-41e5-952e-8362dc7a5366"}
  let(:stored_body_obj_url) { "#{uber_container_url}/#{root_container}/#{body_container_id}" }
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:target_stmts) { RDF::Graph.new.from_ttl(target_ttl).statements }
  let(:target_container_id) {"#{base_container_id}/t/0a/b5/36/9d/0ab5369d-f872-4488-8f1e-3143819b94bf"}
  let(:stored_target_obj_url) {"#{uber_container_url}/#{root_container}/#{target_container_id}"}
  let(:ldp_anno) {
    a = Triannon::AnnotationLdp.new
    a.load_statements_into_graph base_stmts
    a
  }

  describe '#map_choice' do
    it "default, item both ContentAsText" do
      stored_default_url = "#{stored_body_obj_url}#default"
      default_chars = "I love this Englishly!"
      stored_item_url = "#{stored_body_obj_url}#item1"
      item_chars = "Je l'aime en Francais!"
      body_container_stmts = RDF::Turtle::Reader.new("
        @prefix cnt: <http://www.w3.org/2011/content#> .
        @prefix dc11: <http://purl.org/dc/elements/1.1/> .
        @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <#{stored_body_obj_url}> a oa:Choice;
           oa:default <#{stored_default_url}>;
           oa:item <#{stored_item_url}> .

        <#{stored_default_url}> a dcmitype:Text,
             cnt:ContentAsText;
           dc11:language \"en\";
           cnt:chars \"#{default_chars}\" .

        <#{stored_item_url}> a dcmitype:Text,
             cnt:ContentAsText;
           dc11:language \"fr\";
           cnt:chars \"#{item_chars}\" .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      mapper.map_choice(body_uri, RDF::Vocab::OA.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasBody, nil]
      expect(solns.count).to eq 1
      body_blank_node = solns.first.object
      blank_node_solns = mapper.oa_graph.query [body_blank_node, nil, nil]
      expect(blank_node_solns.count).to eq 3
      expect(blank_node_solns).to include [body_blank_node, RDF.type, RDF::Vocab::OA.Choice]

      default_solns = mapper.oa_graph.query [body_blank_node, RDF::Vocab::OA.default, nil]
      expect(default_solns.count).to eq 1
      default_blank_node = default_solns.first.object
      default_node_subject_solns = mapper.oa_graph.query [default_blank_node, nil, nil]
      expect(default_node_subject_solns.count).to eq 4
      expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
      expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
      expect(default_node_subject_solns).to include [default_blank_node, RDF::DC11.language, "en"]
      expect(default_node_subject_solns).to include [default_blank_node, RDF::Vocab::CNT.chars, default_chars]

      item_solns = mapper.oa_graph.query [body_blank_node, RDF::Vocab::OA.item, nil]
      expect(item_solns.count).to eq 1
      item_blank_node = item_solns.first.object
      item_node_subject_solns = mapper.oa_graph.query [item_blank_node, nil, nil]
      expect(item_node_subject_solns.count).to eq 4
      expect(item_node_subject_solns).to include [item_blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
      expect(item_node_subject_solns).to include [item_blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
      expect(item_node_subject_solns).to include [item_blank_node, RDF::DC11.language, "fr"]
      expect(item_node_subject_solns).to include [item_blank_node, RDF::Vocab::CNT.chars, item_chars]

      # should get no triples with stored default or item object urls
      expect(mapper.oa_graph.query([RDF::URI.new(stored_default_url), nil, nil]).size).to eql 0
      expect(mapper.oa_graph.query([RDF::URI.new(stored_item_url), nil, nil]).size).to eql 0
    end
    it "default, item both external URIs (default w addl metadata)" do
      stored_default_url = "#{stored_target_obj_url}#default"
      default_url = "http://some.external.ref/default"
      stored_item_url = "#{stored_target_obj_url}#item"
      item_url = "http://some.external.ref/item"
      target_container_stmts = RDF::Turtle::Reader.new("
        @prefix oa: <http://www.w3.org/ns/oa#> .
        @prefix triannon: <http://triannon.stanford.edu/ns/> .

        <#{stored_default_url}> a oa:SemanticTag;
           triannon:externalReference <#{default_url}> .

        <#{stored_item_url}> triannon:externalReference <#{item_url}> .

        <#{stored_target_obj_url}> a oa:Choice;
           oa:default <#{stored_default_url}>;
           oa:item <#{stored_item_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      mapper.map_choice(target_uri, RDF::Vocab::OA.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasTarget, nil]
      expect(solns.count).to eq 1
      target_blank_node = solns.first.object
      target_blank_node_solns = mapper.oa_graph.query [target_blank_node, nil, nil]
      expect(target_blank_node_solns.count).to eq 3
      expect(target_blank_node_solns).to include [target_blank_node, RDF.type, RDF::Vocab::OA.Choice]
      default_uri_obj = RDF::URI.new(default_url)
      expect(target_blank_node_solns).to include [target_blank_node, RDF::Vocab::OA.default, default_uri_obj]
      expect(target_blank_node_solns).to include [target_blank_node, RDF::Vocab::OA.item, RDF::URI.new(item_url)]

      default_url_subj_solns = mapper.oa_graph.query [default_uri_obj, nil, nil]
      expect(default_url_subj_solns.size).to eql 1
      expect(default_url_subj_solns).to include [default_uri_obj, RDF.type, RDF::Vocab::OA.SemanticTag]

      expect(mapper.oa_graph.query([RDF::URI.new(item_url), nil, nil]).size).to eql 0

      # should get no triples with stored default or item object urls
      expect(mapper.oa_graph.query([RDF::URI.new(stored_default_url), nil, nil]).size).to eql 0
      expect(mapper.oa_graph.query([RDF::URI.new(stored_item_url), nil, nil]).size).to eql 0
    end
    it "three images" do
      stored_default_url = "#{stored_target_obj_url}#default"
      stored_item1_url = "#{stored_target_obj_url}#item1"
      stored_item2_url = "#{stored_target_obj_url}#item2"
      default_url = "http://image.com/small"
      item1_url = "http://images.com/large.jpg"
      item2_url = "http://images.com/small.jpg"
      target_container_stmts = RDF::Turtle::Reader.new("
        @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
        @prefix oa: <http://www.w3.org/ns/oa#> .
        @prefix triannon: <http://triannon.stanford.edu/ns/> .

        <#{stored_default_url}> a dcmitype:Image;
           triannon:externalReference <#{default_url}> .

        <#{stored_item1_url}> a dcmitype:Image;
           triannon:externalReference <#{item1_url}> .

        <#{stored_item2_url}> a dcmitype:Image;
           triannon:externalReference <#{item2_url}> .

        <#{stored_target_obj_url}> a oa:Choice;
           oa:default <#{stored_default_url}>;
           oa:item <#{stored_item1_url}>;
           oa:item <#{stored_item2_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      mapper.map_choice(target_uri, RDF::Vocab::OA.hasTarget)

      target_solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasTarget, nil]
      expect(target_solns.count).to eq 1
      target_blank_node = target_solns.first.object
      target_blank_node_solns = mapper.oa_graph.query [target_blank_node, nil, nil]
      expect(target_blank_node_solns.count).to eq 4
      expect(target_blank_node_solns).to include [target_blank_node, RDF.type, RDF::Vocab::OA.Choice]
      default_uri_obj = RDF::URI.new(default_url)
      expect(target_blank_node_solns).to include [target_blank_node, RDF::Vocab::OA.default, default_uri_obj]
      item1_uri_obj = RDF::URI.new(item1_url)
      expect(target_blank_node_solns).to include [target_blank_node, RDF::Vocab::OA.item, item1_uri_obj]
      item2_uri_obj = RDF::URI.new(item2_url)
      expect(target_blank_node_solns).to include [target_blank_node, RDF::Vocab::OA.item, item2_uri_obj]

      default_uri_subj_solns = mapper.oa_graph.query [default_uri_obj, nil, nil]
      expect(default_uri_subj_solns.count).to eql 1
      expect(default_uri_subj_solns).to include [default_uri_obj, RDF.type, RDF::Vocab::DCMIType.Image]

      item1_uri_subj_solns = mapper.oa_graph.query [item1_uri_obj, nil, nil]
      expect(item1_uri_subj_solns.count).to eql 1
      expect(item1_uri_subj_solns).to include [item1_uri_obj, RDF.type, RDF::Vocab::DCMIType.Image]

      item2_uri_subj_solns = mapper.oa_graph.query [item2_uri_obj, nil, nil]
      expect(item2_uri_subj_solns.count).to eql 1
      expect(item2_uri_subj_solns).to include [item2_uri_obj, RDF.type, RDF::Vocab::DCMIType.Image]

      # should get no triples with stored default or item object urls
      expect(mapper.oa_graph.query([RDF::URI.new(stored_default_url), nil, nil]).size).to eql 0
      expect(mapper.oa_graph.query([RDF::URI.new(stored_item1_url), nil, nil]).size).to eql 0
      expect(mapper.oa_graph.query([RDF::URI.new(stored_item2_url), nil, nil]).size).to eql 0
    end
    it "returns true if it adds statements to oa_graph" do
      stored_default_url = "#{stored_body_obj_url}#default"
      stored_item_url = "#{stored_body_obj_url}#item1"
      body_container_stmts = RDF::Turtle::Reader.new("
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <#{stored_body_obj_url}> a oa:Choice;
           oa:default <#{stored_default_url}>;
           oa:item <#{stored_item_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_choice(body_uri, RDF::Vocab::OA.hasBody)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_choice(target_uri, RDF::Vocab::OA.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if the object doesn't have type Choice" do
      # see 'returns false if it doesn't change oa_graph'
    end
  end #map_choice

end
