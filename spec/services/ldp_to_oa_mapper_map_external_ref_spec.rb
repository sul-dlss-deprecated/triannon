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
  let(:target_container_id) {"#{base_container_id}/t/0a/b5/36/9d/0ab5369d-f872-4488-8f1e-3143819b94bf"}
  let(:target_url) { "http://example.com/solr-integration-test" }
  let(:ldp_anno) {
    a = Triannon::AnnotationLdp.new
    a.load_statements_into_graph base_stmts
    a
  }

  describe '#map_external_ref' do
    it "adds statement with external uri from externalReference statement to oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size
      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasTarget, nil]
      expect(solns.count).to eq 0

      mapper.map_external_ref(target_uri, RDF::Vocab::OA.hasTarget)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasTarget, nil]
      expect(solns.count).to eq 1
      uri = solns.first.object
      expect(uri.class).to eq RDF::URI
      expect(uri.to_s).to eql target_url
      expect(mapper.oa_graph.size).to eql orig_size + 1
    end
    it "returns true if it adds statements to oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_external_ref(target_uri, RDF::Vocab::OA.hasTarget)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_external_ref(body_uri, RDF::Vocab::OA.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if there is no Triannon:externalReference in the container" do
      # see 'returns false if it doesn't change oa_graph'
    end
    it "only maps the first Triannon:externalReference if there is more than one in the container" do
      # there should only ever be one Triannon:externalReference in the object LDP container
      target_url1 = target_url
      target_url2 = "http://purl.stanford.edu/ab123cd4567"
      target_ttl = "
        <#{uber_container_url}/#{root_container}/#{target_container_id}>
        <http://triannon.stanford.edu/ns/externalReference> <#{target_url1}>, <#{target_url2}>; ."
      my_target_stmts = RDF::Graph.new.from_ttl(target_ttl).statements
      ldp_anno.load_statements_into_graph my_target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      expect(mapper.oa_graph.query([nil, RDF::Vocab::OA.hasTarget, nil]).size).to eq 0

      mapper.map_external_ref(target_uri, RDF::Vocab::OA.hasTarget)
      expect(mapper.oa_graph.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI.new(target_url1)]).size).to eq 1
      expect(mapper.oa_graph.query([nil, nil, RDF::URI.new(target_url2)]).size).to eq 0
    end
    it "includes SemanticTags when present" do
      body_ext_url = "http://some.external.ref"
      body_ttl = "
	      @prefix oa: <http://www.w3.org/ns/oa#> .
	      @prefix triannon: <http://triannon.stanford.edu/ns/> .
	      <#{stored_body_obj_url}> a oa:SemanticTag;
	         triannon:externalReference <#{body_ext_url}> ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      mapper.map_external_ref(RDF::URI.new(stored_body_obj_url), RDF::Vocab::OA.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasBody, nil]
      expect(solns.count).to eq 1
      uri_obj = solns.first.object
      expect(uri_obj).to eql RDF::URI.new(body_ext_url)
      expect(mapper.oa_graph.query([uri_obj, RDF.type, RDF::Vocab::OA.SemanticTag]).size).to eql 1
      expect(mapper.oa_graph.size).to eql orig_size + 2
    end
    it "includes additional metadata when present" do
      body_ext_url = "http://some.external.ref"
      body_format = "audio/mpeg3"
      body_ttl = "
	      @prefix oa: <http://www.w3.org/ns/oa#> .
	      @prefix triannon: <http://triannon.stanford.edu/ns/> .
	      @prefix dc11: <http://purl.org/dc/elements/1.1/> .
	      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
	      <#{stored_body_obj_url}> a dcmitype:Sound;
	         triannon:externalReference <#{body_ext_url}>;
	         dc11:format \"#{body_format}\" ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      mapper.map_external_ref(RDF::URI.new(stored_body_obj_url), RDF::Vocab::OA.hasBody)

      solns = mapper.oa_graph.query [nil, RDF::Vocab::OA.hasBody, nil]
      expect(solns.count).to eq 1
      uri_obj = solns.first.object
      expect(uri_obj).to eql RDF::URI.new(body_ext_url)
      expect(mapper.oa_graph.query([uri_obj, RDF.type, RDF::Vocab::DCMIType.Sound]).size).to eql 1
      expect(mapper.oa_graph.query([uri_obj, RDF::DC11.format, body_format]).size).to eql 1
      expect(mapper.oa_graph.size).to eql orig_size + 3
    end
    it "attaches external ref to passed param for subject" do
      body_ext_url = "http://some.external.ref"
      body_ttl = "
	      @prefix oa: <http://www.w3.org/ns/oa#> .
	      @prefix triannon: <http://triannon.stanford.edu/ns/> .
	      <#{stored_body_obj_url}> triannon:externalReference <#{body_ext_url}> ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts
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
      mapper.map_external_ref(RDF::URI.new(stored_body_obj_url), RDF::Vocab::OA.hasBody, target_obj)

      solns = mapper.oa_graph.query [target_obj, nil, nil]
      expect(solns.count).to eq 1
      expect(mapper.oa_graph.query([target_obj, RDF::Vocab::OA.hasBody, RDF::URI.new(body_ext_url)]).size).to eql 1
      expect(mapper.oa_graph.size).to eql orig_size + 1
    end
  end #map_external_ref

end
