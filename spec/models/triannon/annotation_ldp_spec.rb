require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Triannon::AnnotationLdp do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_complete.ttl') }
  let(:anno) {
    a = Triannon::AnnotationLdp.new
    a.annotation_data = anno_ttl
    a
  }

  before(:each) do

  end

  describe "#base_graph" do

    it "creates an RDF::Graph from the annotation_data if the base_graph does not yet exist" do
      g = anno.base_graph

      result = g.query [nil, RDF.type, RDF::OpenAnnotation.Annotation]
      expect(result.first.subject.path).to match /b045e6e7-19de-4cda-a920-04fe119a1df1/
    end
  end

  describe "#base_uri" do
    it "returns the URI to the annotation's main root-level subject" do
      expect(anno.base_uri.path).to match /b045e6e7-19de-4cda-a920-04fe119a1df1/
    end
  end

  describe "#body_uri" do

    it "returns the URI to the resource stored in the annotation's body container" do
      expect(anno.body_uri.path).to match /\/b\/88da6576-3ddf-4bde-9b8b-e520b2c92fdf/
    end
  end

end