require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Triannon::LdpLoader do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_complete.ttl') }

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
      expect(loader.data.anno_ttl).to eq(anno_ttl)
    end

  end

  describe "#load_body" do

    it "retrieves the body by using the hasBody value from the annotation" do
      loader = Triannon::LdpLoader.new 'somekey'
    end

  end

end