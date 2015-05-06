require 'spec_helper'

describe Triannon::LdpToOaMapper, :vcr do
  let(:triannon_anno_container) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"}
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:base_container_id) {"f8/c2/36/de/f8c236de-be13-499d-a1e2-3f6fbd3a89ec"}
  let(:body_container_id) {"#{base_container_id}/b/75/18/5b/af/75185baf-7057-4762-bfb2-432e88221810"}
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:target_stmts) { RDF::Graph.new.from_ttl(target_ttl).statements }
  let(:target_container_id) {"#{base_container_id}/t/07/1b/94/c0/071b94c0-953e-46aa-b21c-2bb201c5ff59"}
  let(:ldp_anno) {
    a = Triannon::AnnotationLdp.new
    a.load_statements_into_graph base_stmts
    a
  }

  describe '#map_choice' do
    let(:stored_body_obj_url) { "#{triannon_anno_container}/#{body_container_id}" }
    it "default, item both ContentAsText" do
      stored_default_url = "http://localhost:8983/fedora/rest/.well-known/genid/ea68448e-e50c-4274-a204-af477a0d8317"
      default_chars = "I love this Englishly!"
      stored_item_url = "http://localhost:8983/fedora/rest/.well-known/genid/6051b00b-24e9-4a10-8b7d-0c44fa5fa469"
      item_chars = "Je l'aime en Francais!"
      body_container_stmts = RDF::Turtle::Reader.new("
      @prefix content: <http://www.w3.org/2011/content#> .
      @prefix dc11: <http://purl.org/dc/elements/1.1/> .
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{stored_item_url}> a dcmitype:Text,
           content:ContentAsText;
         dc11:language \"fr\";
         content:chars \"#{item_chars}\" .

      <#{stored_default_url}> a dcmitype:Text,
           content:ContentAsText;
         dc11:language \"en\";
         content:chars \"#{default_chars}\" .

      <#{stored_body_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Choice;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_body_obj_url}>;
         openannotation:default <#{stored_default_url}>;
         openannotation:item <#{stored_item_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
      stored_target_obj_url = "#{triannon_anno_container}/#{target_container_id}"
      stored_default_url = "http://localhost:8983/fedora/rest/.well-known/genid/ea68448e-e50c-4274-a204-af477a0d8317"
      default_url = "http://some.external.ref/default"
      stored_item_url = "http://localhost:8983/fedora/rest/.well-known/genid/6051b00b-24e9-4a10-8b7d-0c44fa5fa469"
      item_url = "http://some.external.ref/item"
      target_container_stmts = RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{stored_default_url}> a openannotation:SemanticTag;
         triannon:externalReference <#{default_url}> .

      <#{stored_item_url}> triannon:externalReference <#{item_url}> .

      <#{stored_target_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Choice;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_target_obj_url}>;
         openannotation:default <#{stored_default_url}>;
         openannotation:item <#{stored_item_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
      stored_target_obj_url = "#{triannon_anno_container}/#{target_container_id}"
      stored_default_url = "#{stored_target_obj_url}#default"
      stored_item1_url = "#{stored_target_obj_url}#item1"
      stored_item2_url = "#{stored_target_obj_url}#item2"
      default_url = "http://image.com/small"
      item1_url = "http://images.com/large.jpg"
      item2_url = "http://images.com/small.jpg"
      target_container_stmts = RDF::Turtle::Reader.new("
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{stored_default_url}> a dcmitype:Image;
         triannon:externalReference <#{default_url}> .

      <#{stored_item1_url}> a dcmitype:Image;
         triannon:externalReference <#{item1_url}> .

      <#{stored_item2_url}> a dcmitype:Image;
         triannon:externalReference <#{item2_url}> .

      <#{stored_target_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Choice;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_target_obj_url}>;
         openannotation:default <#{stored_default_url}>;
         openannotation:item <#{stored_item1_url}>;
         openannotation:item <#{stored_item2_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
      stored_default_url = "http://localhost:8983/fedora/rest/.well-known/genid/ea68448e-e50c-4274-a204-af477a0d8317"
      stored_item_url = "http://localhost:8983/fedora/rest/.well-known/genid/6051b00b-24e9-4a10-8b7d-0c44fa5fa469"
      body_container_stmts = RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{stored_body_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Choice;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_body_obj_url}>;
         openannotation:default <#{stored_default_url}>;
         openannotation:item <#{stored_item_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_choice(body_uri, RDF::Vocab::OA.hasBody)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
