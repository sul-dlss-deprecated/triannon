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
  let(:body_obj_url) {"#{uber_container_url}/#{root_container}/#{body_container_id}"}
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:target_stmts) { RDF::Graph.new.from_ttl(target_ttl).statements }
  let(:target_container_id) {"#{base_container_id}/t/0a/b5/36/9d/0ab5369d-f872-4488-8f1e-3143819b94bf"}
  let(:target_obj_url) {"#{uber_container_url}/#{root_container}/#{target_container_id}"}
  let(:ldp_anno) {
    a = Triannon::AnnotationLdp.new
    a.load_statements_into_graph base_stmts
    a
  }
  let(:base_url) {
    base_url = Triannon.config[:triannon_base_url].strip
    base_url.chop! if base_url.end_with?('/')
  }

  describe ".ldp_to_oa" do
    it "maps an AnnotationLdp to an OA::Graph" do
      ldp_anno.load_statements_into_graph body_stmts
      ldp_anno.load_statements_into_graph target_stmts
      oa_graph = Triannon::LdpToOaMapper.ldp_to_oa(ldp_anno, root_container)

      expect(oa_graph).to be_a OA::Graph
      resp = oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(resp.first.subject.to_s).to eq "#{base_url}/#{root_container}/#{base_container_id}"
    end
    it "calls #extract_base" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_base)
      Triannon::LdpToOaMapper.ldp_to_oa(ldp_anno, root_container)
    end
    it "calls #extract_bodies" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_bodies)
      Triannon::LdpToOaMapper.ldp_to_oa(ldp_anno, root_container)
    end
    it "calls #extract_targets" do
      expect_any_instance_of(Triannon::LdpToOaMapper).to receive(:extract_targets)
      Triannon::LdpToOaMapper.ldp_to_oa(ldp_anno, root_container)
    end
  end

  describe "#extract_base" do
    let(:mapper) { Triannon::LdpToOaMapper.new(ldp_anno, root_container) }

    it "extracts the id from the root subject" do
      mapper.extract_base
      expect(mapper.id).to eq '67/c0/18/9d/67c0189d-56d4-47fb-abea-1f995187b358'
    end

    it "builds the base identifier from the triannon.yml triannon_base_url and @id" do
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to eq "#{base_url}/#{root_container}/#{base_container_id}"
    end

    it "base identifier doesn't have double slash before id if triannon_base_url ends in slash" do
      orig_val = Triannon.config[:triannon_base_url]
      Triannon.config[:triannon_base_url] = "http://mine.com/annotations/"  # with trailing slash
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to match "http://mine.com/annotations/#{root_container}/#{base_container_id}"
      Triannon.config[:triannon_base_url] = "http://mine.com/annotations"  # without trailing slash
      mapper.extract_base
      soln = mapper.oa_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(soln.first.subject.to_s).to match "http://mine.com/annotations/#{root_container}/#{base_container_id}"
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
      my_mapper = Triannon::LdpToOaMapper.new(my_ldp_anno, root_container)
      my_mapper.extract_base
      soln = my_mapper.oa_graph.query [nil, RDF::Vocab::OA.annotatedAt, nil]
      expect(soln.count).to eq 1
      expect(soln.first.object.to_s).to eq "2014-09-03T17:16:13Z"
    end
  end #extract_base

  describe "#extract_bodies" do
    it "calls #map_external_ref when body is an external ref" do
      body_ttl = "<#{body_obj_url}> <http://triannon.stanford.edu/ns/externalReference> <http://some.external.ref> ."
      my_body_stmts = RDF::Graph.new.from_ttl(body_ttl).statements
      ldp_anno.load_statements_into_graph my_body_stmts
      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      expect(mapper).to receive(:map_external_ref)
      mapper.extract_bodies
    end
    it "calls #map_content_as_text when body is ContentAsText" do
      ldp_anno.load_statements_into_graph body_stmts
      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      expect(mapper).to receive(:map_content_as_text)
      mapper.extract_bodies
    end
    it "calls #map_specific_resource when body is SpecificResource" do
      body_container_stmts =  RDF::Turtle::Reader.new("
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <#{body_obj_url}> a oa:SpecificResource;
           oa:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f8/75/34/2e/f875342e-d8d7-475a-8085-1e07f1f8b674>;
           oa:hasSource <#{body_obj_url}#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      expect(mapper).to receive(:map_specific_resource)
      mapper.extract_bodies
    end
    it "calls #map_choice when body is Choice" do
      body_container_stmts = RDF::Turtle::Reader.new("
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <#{body_obj_url}> a oa:Choice;
           oa:default <#{body_obj_url}#default>;
           oa:item <#{body_obj_url}#item1> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph body_container_stmts

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      expect(mapper).to receive(:map_choice)
      mapper.extract_bodies
    end
  end #extract_bodies

  describe "#extract_targets" do
    it "calls #map_external_ref when target is an external ref" do
      ldp_anno.load_statements_into_graph target_stmts
      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      expect(mapper).to receive(:map_external_ref)
      mapper.extract_targets
    end
    it "calls #map_specific_resource when target is SpecificResource" do
      target_container_stmts =  RDF::Turtle::Reader.new("
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <#{target_obj_url}> a oa:SpecificResource;
           oa:hasSelector <http://localhost:8983/fedora/rest/.well-known/genid/f8/75/34/2e/f875342e-d8d7-475a-8085-1e07f1f8b674>;
           oa:hasSource <#{target_obj_url}#source> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      expect(mapper).to receive(:map_specific_resource)
      mapper.extract_targets
    end
    it "calls #map_choice when target is Choice" do
      target_container_stmts = RDF::Turtle::Reader.new("
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <#{target_obj_url}> a oa:Choice;
           oa:default <#{target_obj_url}#default>;
           oa:item <#{target_obj_url}#item1> .
      ").statements.to_a
      ldp_anno.load_statements_into_graph target_container_stmts

      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      expect(mapper).to receive(:map_choice)
      mapper.extract_targets
    end
  end #extract_targets

end
