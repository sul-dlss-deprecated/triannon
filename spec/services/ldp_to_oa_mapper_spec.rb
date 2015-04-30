require 'spec_helper'

describe Triannon::LdpToOaMapper, :vcr do
  let(:triannon_anno_container) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"}
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:body_stmts) { RDF::Graph.new.from_ttl(body_ttl).statements }
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:target_stmts) { RDF::Graph.new.from_ttl(target_ttl).statements }
  let(:ldp_anno) {
    a = Triannon::AnnotationLdp.new
    a.load_statements_into_graph base_stmts
    a
  }

  describe ".ldp_to_oa" do
    it "maps an AnnotationLdp to an OA::Graph" do
      ldp_anno.load_statements_into_graph body_stmts
      ldp_anno.load_statements_into_graph target_stmts
      oa_graph = Triannon::LdpToOaMapper.ldp_to_oa ldp_anno

      expect(oa_graph).to be_a OA::Graph
      resp = oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation ]
      expect(resp.first.subject.to_s).to eq "#{Triannon.config[:triannon_base_url]}/deb27887-1241-4ccc-a09c-439293d73fbb"
    end
    it "calls #extract_base" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_base)
      Triannon::LdpToOaMapper.ldp_to_oa ldp_anno
    end
    it "calls #extract_bodies" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_bodies)
      Triannon::LdpToOaMapper.ldp_to_oa ldp_anno
    end
    it "calls #extract_targets" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_targets)
      Triannon::LdpToOaMapper.ldp_to_oa ldp_anno
    end
  end

  describe "#extract_base" do
    let(:mapper) { Triannon::LdpToOaMapper.new ldp_anno }

    it "extracts the id from the root subject" do
      mapper.extract_base
      expect(mapper.id).to eq 'deb27887-1241-4ccc-a09c-439293d73fbb'
    end

    it "builds the base identifier from the triannon.yml triannon_base_url and @id" do
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to eq "#{Triannon.config[:triannon_base_url]}/deb27887-1241-4ccc-a09c-439293d73fbb"
    end

    it "base identifier doesn't have double slash before id if triannon_base_url ends in slash" do
      orig_val = Triannon.config[:triannon_base_url]
      Triannon.config[:triannon_base_url] = "http://mine.com/annotations/"  # with trailing slash
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to match "http://mine.com/annotations/deb27887-1241-4ccc-a09c-439293d73fbb"
      Triannon.config[:triannon_base_url] = "http://mine.com/annotations"  # without trailing slash
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to match "http://mine.com/annotations/deb27887-1241-4ccc-a09c-439293d73fbb"
      Triannon.config[:triannon_base_url] = orig_val
    end

    it "checks the RDF.type to be RDF::Vocab::OA.Annotation" do
      skip "raise an exception if it is not?"
    end

    it "extracts the motivations" do
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF::Vocab::OA.motivatedBy, nil]
      expect(soln.count).to eq 1
      expect(soln.first.object).to eq RDF::Vocab::OA.commenting
    end

    it "extracts annotatedAt" do
      prov_base_ttl = File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base_prov.ttl')
      my_ldp_anno = Triannon::AnnotationLdp.new
      my_ldp_anno.load_statements_into_graph RDF::Graph.new.from_ttl(prov_base_ttl).statements
      my_mapper = Triannon::LdpToOaMapper.new my_ldp_anno
      my_mapper.extract_base
      soln = my_mapper.oa_graph.query [nil, RDF::Vocab::OA.annotatedAt, nil]
      expect(soln.count).to eq 1
      expect(soln.first.object.to_s).to eq "2015-01-07T18:01:21Z"
    end
  end #extract_base

  describe "#extract_bodies" do
    it "calls #map_external_ref when body is an external ref" do
      body_ttl = "
        <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23>
        <http://triannon.stanford.edu/ns/externalReference> <http://some.external.ref> ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_external_ref)
      mapper.extract_bodies
    end
    it "calls #map_content_as_text when body is ContentAsText" do
      ldp_anno.load_statements_into_graph body_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_content_as_text)
      mapper.extract_bodies
    end
    it "calls #map_specific_resource when body is SpecificResource" do
      body_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23>;
         openannotation:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
         openannotation:hasSource <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_specific_resource)
      mapper.extract_bodies
    end
    it "calls #map_choice when body is Choice" do
      body_container_stmts = RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Choice;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23>;
         openannotation:default <http://localhost:8983/fedora/rest/.well-known/genid/ea68448e-e50c-4274-a204-af477a0d8317>;
         openannotation:item <http://localhost:8983/fedora/rest/.well-known/genid/6051b00b-24e9-4a10-8b7d-0c44fa5fa469> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_choice)
      mapper.extract_bodies
    end
  end #extract_bodies

  describe "#extract_targets" do
    it "calls #map_external_ref when target is an external ref" do
      ldp_anno.load_statements_into_graph target_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_external_ref)
      mapper.extract_targets
    end
    it "calls #map_specific_resource when target is SpecificResource" do
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1>;
         openannotation:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
         openannotation:hasSource <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_specific_resource)
      mapper.extract_targets
    end
    it "calls #map_choice when target is Choice" do
      target_container_stmts = RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Choice;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1>;
         openannotation:default <http://localhost:8983/fedora/rest/.well-known/genid/ea68448e-e50c-4274-a204-af477a0d8317>;
         openannotation:item <http://localhost:8983/fedora/rest/.well-known/genid/6051b00b-24e9-4a10-8b7d-0c44fa5fa469> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper).to receive(:map_choice)
      mapper.extract_targets
    end
  end #extract_targets

  describe '#map_external_ref' do
    let(:target_url) { "http://purl.stanford.edu/kq131cs7229" }
    it "adds statement with external uri from externalReference statement to oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_external_ref(target_uri, RDF::Vocab::OA.hasTarget)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      body_uri = ldp_anno.body_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
        <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1>
        <http://triannon.stanford.edu/ns/externalReference> <#{target_url1}>, <#{target_url2}>; ."
      my_target_stmts = RDF::Graph.new.from_ttl(target_ttl).statements
      ldp_anno.load_statements_into_graph my_target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      expect(mapper.oa_graph.query([nil, RDF::Vocab::OA.hasTarget, nil]).size).to eq 0

      mapper.map_external_ref(target_uri, RDF::Vocab::OA.hasTarget)
      expect(mapper.oa_graph.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI.new(target_url1)]).size).to eq 1
      expect(mapper.oa_graph.query([nil, nil, RDF::URI.new(target_url2)]).size).to eq 0
    end
    it "includes SemanticTags when present" do
      body_ext_url = "http://some.external.ref"
      stored_body_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23"
      body_ttl = "
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      <#{stored_body_obj_url}> a openannotation:SemanticTag;
         triannon:externalReference <#{body_ext_url}> ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
      stored_body_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23"
      body_ttl = "
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix dc11: <http://purl.org/dc/elements/1.1/> .
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      <#{stored_body_obj_url}> a dcmitype:Sound;
         triannon:externalReference <#{body_ext_url}>;
         dc11:format \"#{body_format}\" ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
      stored_body_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23"
      body_ttl = "
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      <#{stored_body_obj_url}> triannon:externalReference <#{body_ext_url}> ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts
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
      mapper.map_external_ref(RDF::URI.new(stored_body_obj_url), RDF::Vocab::OA.hasBody, target_obj)

      solns = mapper.oa_graph.query [target_obj, nil, nil]
      expect(solns.count).to eq 1
      expect(mapper.oa_graph.query([target_obj, RDF::Vocab::OA.hasBody, RDF::URI.new(body_ext_url)]).size).to eql 1
      expect(mapper.oa_graph.size).to eql orig_size + 1
    end
  end #map_external_ref

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
      expect(blank_node_solns).to include [blank_node, RDF::Vocab::CNT.chars, "I love this!"]
    end
    it "adds all relevant statements in skolemized blank node to @oa_graph" do
      body_container_stmts = RDF::Turtle::Reader.new('
      @prefix content: <http://www.w3.org/2011/content#> .
      @prefix dc11: <http://purl.org/dc/elements/1.1/> .
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           dcmitype:Text,
           content:ContentAsText;
         dc11:format "text/plain";
         dc11:language "en";
         content:chars "I love this!";
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23> .
      ').statements.to_a
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
      stored_body_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23"
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

  describe '#map_specific_resource' do
    it "simple source" do
      # see text position selector test
    end
    it "source with add'l properties" do
      # see fragment selector test
    end
    it "TextPositionSelector" do
      stored_target_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "http://purl.stanford.edu/kq131cs7229.html"
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{stored_target_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_target_obj_url}>;
         openannotation:hasSelector <#{stored_selector_obj_url}>;
         openannotation:hasSource <#{stored_source_obj_url}> .

      <#{stored_source_obj_url}> triannon:externalReference <#{source_url}> .

      <#{stored_selector_obj_url}> a openannotation:TextPositionSelector;
         openannotation:start \"0\"^^xsd:long;
         openannotation:end \"66\"^^xsd:long .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
# FIXME:  these should be converted back to nonNegativeInteger, per OA spec
# See https://github.com/sul-dlss/triannon/issues/78
      expect(start_obj.datatype).to eql RDF::XSD.long
      end_obj_solns = mapper.oa_graph.query [selector_blank_node, RDF::Vocab::OA.end, nil]
      expect(end_obj_solns.count).to eq 1
      end_obj = end_obj_solns.first.object
      expect(end_obj.to_s).to eql "66"
      expect(end_obj.datatype).to eql RDF::XSD.long

      # should get no triples with stored selector or source object urls
      expect(mapper.oa_graph.query([RDF::URI.new(stored_source_obj_url), nil, nil]).size).to eql 0
      expect(mapper.oa_graph.query([RDF::URI.new(stored_selector_obj_url), nil, nil]).size).to eql 0
    end
    it "start and end in TextPositionSelector have type nonNegativeIntegers" do
      # See https://github.com/sul-dlss/triannon/issues/78
      skip 'converting returned xsd:long to xsd:nonNegativeInteger not yet implemented'
    end
    it "TextQuoteSelector" do
      stored_target_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "http://purl.stanford.edu/kq131cs7229.html"
      suffix = " and The Canonical Epistles,"
      exact = "third and fourth Gospels"
      prefix = "manuscript which comprised the "
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{stored_target_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_target_obj_url}>;
         openannotation:hasSelector <#{stored_selector_obj_url}>;
         openannotation:hasSource <#{stored_source_obj_url}> .

      <#{stored_source_obj_url}> triannon:externalReference <#{source_url}> .

      <#{stored_selector_obj_url}> a openannotation:TextQuoteSelector;
         openannotation:suffix \"#{suffix}\";
         openannotation:exact \"#{exact}\";
         openannotation:prefix \"#{prefix}\" .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
      stored_target_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
      stored_source_obj_url = "#{stored_target_obj_url}#source"
      stored_selector_obj_url = "http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674"
      source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
      conforms_to_url = "http://www.w3.org/TR/media-frags/"
      frag_value = "xywh=0,0,200,200"
      # note that hash URIs (e.g. #source) and blank nodes (e.g. selector) are conveniently returned in the same container
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      @prefix dcterms: <http://purl.org/dc/terms/> .
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{stored_target_obj_url}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{stored_target_obj_url}>;
         openannotation:hasSelector <#{stored_selector_obj_url}>;
         openannotation:hasSource <#{stored_source_obj_url}> .

      <#{stored_source_obj_url}> a dcmitype:Image;
         triannon:externalReference <#{source_url}> .

      <#{stored_selector_obj_url}> a openannotation:FragmentSelector;
         rdf:value \"#{frag_value}\";
         dcterms:conformsTo <#{conforms_to_url}> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
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
#    it "DataPositionSelector" do
#      skip 'DataPositionSelector not yet implemented'
#    end
#    it "SvgSelector" do
#      skip 'SvgSelector not yet implemented'
#    end
    it "returns true if it adds statements to oa_graph" do
      target_container_stmts =  RDF::Turtle::Reader.new("
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix triannon: <http://triannon.stanford.edu/ns/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1>;
         openannotation:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
         openannotation:hasSource <#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_specific_resource(target_uri, RDF::Vocab::OA.hasTarget)).to be true
      expect(mapper.oa_graph.size).to be > orig_size
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      target_uri = ldp_anno.target_uris.first

      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      orig_size = mapper.oa_graph.size

      expect(mapper.map_specific_resource(target_uri, RDF::Vocab::OA.hasTarget)).to be false
      expect(mapper.oa_graph.size).to eql orig_size
    end
    it "doesn't change @oa_graph if the object doesn't have type SpecificResource" do
      # see 'returns false if it doesn't change oa_graph'
    end
  end #map_specific_resource

  describe '#map_choice' do
    let(:stored_body_obj_url) { "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23" }
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
      stored_target_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
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
      stored_target_obj_url = "#{triannon_anno_container}/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
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
