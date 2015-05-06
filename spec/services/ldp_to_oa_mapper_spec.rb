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
  let(:target_container_id) {"#{base_container_id}/t/07/1b/94/c0/071b94c0-953e-46aa-b21c-2bb201c5ff59"}
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
      resp = oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(resp.first.subject.to_s).to eq "#{Triannon.config[:triannon_base_url]}/#{base_container_id}"
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
      expect(mapper.id).to eq 'f8/c2/36/de/f8c236de-be13-499d-a1e2-3f6fbd3a89ec'
    end

    it "builds the base identifier from the triannon.yml triannon_base_url and @id" do
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to eq "#{Triannon.config[:triannon_base_url]}/#{base_container_id}"
    end

    it "base identifier doesn't have double slash before id if triannon_base_url ends in slash" do
      orig_val = Triannon.config[:triannon_base_url]
      Triannon.config[:triannon_base_url] = "http://mine.com/annotations/"  # with trailing slash
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to match "http://mine.com/annotations/#{base_container_id}"
      Triannon.config[:triannon_base_url] = "http://mine.com/annotations"  # without trailing slash
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to match "http://mine.com/annotations/#{base_container_id}"
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
      expect(soln.first.object.to_s).to eq "2014-09-03T17:16:13Z"
    end
  end #extract_base

  describe "#extract_bodies" do
    it "calls #map_external_ref when body is an external ref" do
      body_ttl = "
        <http://localhost:8983/fedora/rest/anno/#{body_container_id}>
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

      <#{triannon_anno_container}/#{body_container_id}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/#{body_container_id}>;
         openannotation:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
         openannotation:hasSource <#{triannon_anno_container}/#{body_container_id}#source> .
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

      <#{triannon_anno_container}/#{body_container_id}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Choice;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/#{body_container_id}>;
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

      <#{triannon_anno_container}/#{target_container_id}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:SpecificResource;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/#{target_container_id}>;
         openannotation:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f875342e-d8d7-475a-8085-1e07f1f8b674>;
         openannotation:hasSource <#{triannon_anno_container}/#{target_container_id}#source> .
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

      <#{triannon_anno_container}/#{target_container_id}> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Choice;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <#{triannon_anno_container}/#{target_container_id}>;
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

end
