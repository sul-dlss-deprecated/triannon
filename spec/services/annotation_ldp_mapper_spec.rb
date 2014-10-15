require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Triannon::AnnotationLdpMapper do
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }

  describe ".ldp_to_oa" do

    it "maps an AnnotationLdp to an OA RDF::Graph" do
      ldp_anno = Triannon::AnnotationLdp.new
      ldp_anno.load_data_into_graph anno_ttl
      ldp_anno.load_data_into_graph body_ttl
      ldp_anno.load_data_into_graph target_ttl
      oa_graph = Triannon::AnnotationLdpMapper.ldp_to_oa ldp_anno

      resp = oa_graph.query [nil,RDF.type, RDF::OpenAnnotation.Annotation ]
      expect(resp.first.subject.to_s).to match /blah/
    end

  end

  describe "#extract_base" do
    let(:ldp_anno) {
      a = Triannon::AnnotationLdp.new
      a.load_data_into_graph anno_ttl
      a
    }

    let(:mapper) { Triannon::AnnotationLdpMapper.new ldp_anno  }

    # TODO what to do about id in the graph?  Config option? Config.open_annotation_base_uri ?
    it "extracts the id from the root subject" do
      mapper.extract_base
      expect(mapper.id).to eq 'deb27887-1241-4ccc-a09c-439293d73fbb'
    end

    # TODO raise an exception if it is not?
    it "checks the RDF.type to be RDF::OpenAnnotation.Annotation" do
      skip
    end

    it "extracts the motivations" do
      mapper.extract_base

      res = mapper.oa_graph.query [nil, RDF::OpenAnnotation.motivatedBy, nil]
      expect(res.count).to eq 1
      expect(res.first.object).to eq RDF::OpenAnnotation.commenting
    end
  end

  describe "#extract_body" do
    it "grabs the chars if the RDF.type is ContextAsText" do

    end

    it "sets the hasBody statement" do

    end
  end

  describe "#extract_target" do
    it "grabs the url if there's an externalRefence" do

    end

    it "sets the hasTarget url" do

    end
  end

end
