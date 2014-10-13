require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Triannon::AnnotationLdp do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_complete.ttl') }
  let(:anno) { Triannon::AnnotationLdp.new }

  before(:each) do

  end

  describe "#graph" do

    it "creates an RDF::Graph if it does not yet exist" do
      g = anno.graph
      expect(g.count).to eq 0
    end
  end

  describe "#base_uri" do
    it "returns the URI to the annotation's main root-level subject" do
      anno.load_data_into_graph anno_ttl
      expect(anno.base_uri.path).to match /deb27887-1241-4ccc-a09c-439293d73fbb/
    end
  end

  describe "#body_uri" do

    it "returns the URI to the resource stored in the annotation's body container" do
      anno.load_data_into_graph anno_ttl
      expect(anno.body_uri.path).to match /\/b\/e14b93b7-3a88-4eb5-9688-7dea7f482d23/
    end
  end

  describe "load_data_into_graph" do
    it "takes incoming turtle and loads it into base_graph" do
      anno.load_data_into_graph anno_ttl

      result = anno.graph.query [nil, RDF.type, RDF::OpenAnnotation.Annotation]
      expect(result.first.subject.path).to match /deb27887-1241-4ccc-a09c-439293d73fbb/
    end

    it "handles nil data" do
      skip
    end

    it "does something with data other than turtle" do
      skip
    end
  end

end