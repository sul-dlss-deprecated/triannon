require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Triannon::LdpLoader do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_complete.ttl') }
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }

  describe "#load_annotation" do


    # TODO super brittle since it stubs the whole http interaction
    it "retrives the ttl data for an annotation when given an id" do
      conn = double()
      resp = double()
      allow(resp).to receive(:body).and_return(anno_ttl)
      allow(conn).to receive(:get).and_return(resp)

      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:conn).and_return(conn)

      loader.load_annotation
      expect(loader.annotation.graph.class).to eq(RDF::Graph)
      expect(loader.annotation.graph.count).to be > 1
    end

    it "no triple in the graph should have the body uri as a subject" do
      skip
    end

    it "no triple in the graph should have the target uri as a subject" do
      skip
    end

  end

  describe "#load_body" do

    it "retrieves the body by using the hasBody value from the annotation" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl, body_ttl)
      loader.load_annotation
      loader.load_body

      result = loader.annotation.graph.query [loader.annotation.body_uri, RDF::Content.chars, nil]
      expect(result.first.object.to_s).to match /I love this/
    end

    it "has triples in the graph where the subject is the body uri" do

    end

  end

end