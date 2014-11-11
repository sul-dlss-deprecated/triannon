require 'spec_helper'

describe Triannon::LdpLoader do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:root_anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_root_anno_container.ttl') }

  describe "#load_anno_container" do

    # TODO super brittle since it stubs the whole http interaction
    it "retrives the ttl data for an annotation when given an id" do
      conn = double()
      resp = double()
      allow(resp).to receive(:body).and_return(anno_ttl)
      allow(conn).to receive(:get).and_return(resp)

      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:conn).and_return(conn)

      loader.load_anno_container
      expect(loader.ldp_annotation.graph.class).to eq(RDF::Graph)
      expect(loader.ldp_annotation.graph.count).to be > 1
    end

    it "no triple in the graph should have the body uri as a subject" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl)
      loader.load_anno_container
      body_uri = loader.ldp_annotation.body_uris.first
      result = loader.ldp_annotation.graph.query [body_uri, nil, nil]
      expect(result.size).to eq 0
    end

    it "no triple in the graph should have the target uri as a subject" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl)
      loader.load_anno_container
      target_uri = loader.ldp_annotation.target_uris.first
      result = loader.ldp_annotation.graph.query [target_uri, nil, nil]
      expect(result.size).to eq 0
    end
  end

  describe "#load_bodies" do
    it "retrieves the bodies via hasBody objects in anno container" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl, body_ttl)
      loader.load_anno_container
      loader.load_bodies
      body_uri = loader.ldp_annotation.body_uris.first
      result = loader.ldp_annotation.graph.query [body_uri, RDF::Content.chars, nil]
      expect(result.first.object.to_s).to match /I love this/
    end
    it "retrieves triples about external refs" do
      loader = Triannon::LdpLoader.new 'somekey'
      my_body_ttl = File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body_ext_refs.ttl')
      allow(loader).to receive(:get_ttl).and_return(anno_ttl, my_body_ttl)
      loader.load_anno_container
      loader.load_bodies
      body_uri = loader.ldp_annotation.body_uris.first
      ext_ref_solns = loader.ldp_annotation.graph.query [body_uri, RDF::Triannon.externalReference, nil]
      expect(ext_ref_solns.count).to eql 1
      expect(ext_ref_solns).to include [body_uri, RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Love")]
      expect(loader.ldp_annotation.graph.query([body_uri, RDF.type, RDF::OpenAnnotation.SemanticTag]).count).to eql 1
    end
  end

  describe "#load_targets" do
    it "retrieves the targets via hasTarget objects in anno container" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).and_return(anno_ttl, target_ttl)
      loader.load_anno_container
      loader.load_targets
      target_uri = loader.ldp_annotation.target_uris.first
      result = loader.ldp_annotation.graph.query [target_uri, RDF::Triannon.externalReference, nil]
      expect(result.first.object.to_s).to match /kq131cs7229/
    end
    it "retrieves triples about external refs" do
      loader = Triannon::LdpLoader.new 'somekey'
      my_target_ttl = File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target_ext_refs.ttl')
      allow(loader).to receive(:get_ttl).and_return(anno_ttl, my_target_ttl)
      loader.load_anno_container
      loader.load_targets
      target_uri = loader.ldp_annotation.target_uris.first
      
      default_uri_obj = RDF::URI.new(target_uri.to_s + "#default")
      default_uri_solns = loader.ldp_annotation.graph.query [default_uri_obj, nil, nil]
      expect(default_uri_solns.count).to eql 2
      expect(default_uri_solns).to include [default_uri_obj, RDF::Triannon.externalReference, RDF::URI.new("http://images.com/small")]
      expect(default_uri_solns).to include [default_uri_obj, RDF.type, RDF::DCMIType.Image]

      item1_uri_obj = RDF::URI.new(target_uri.to_s + "#item1")
      item1_uri_solns = loader.ldp_annotation.graph.query [item1_uri_obj, nil, nil]
      expect(item1_uri_solns.count).to eql 2
      expect(item1_uri_solns).to include [item1_uri_obj, RDF::Triannon.externalReference, RDF::URI.new("http://images.com/large")]
      expect(item1_uri_solns).to include [item1_uri_obj, RDF.type, RDF::DCMIType.Image]

      item2_uri_obj = RDF::URI.new(target_uri.to_s + "#item2")
      item2_uri_solns = loader.ldp_annotation.graph.query [item2_uri_obj, nil, nil]
      expect(item2_uri_solns.count).to eql 2
      expect(item2_uri_solns).to include [item2_uri_obj, RDF::Triannon.externalReference, RDF::URI.new("http://images.com/huge")]
      expect(item2_uri_solns).to include [item2_uri_obj, RDF.type, RDF::DCMIType.Image]
    end
  end

  describe ".find_all" do
    it "returns an array of Triannon::Annnotation objects, with just id set" do
      loader = Triannon::LdpLoader.new
      allow(loader).to receive(:get_ttl).and_return(root_anno_ttl)
      objs = loader.find_all

      expect(objs.size).to be > 0
      expect(objs.first.class).to eq Triannon::Annotation
      expect(objs.first.id).to_not be_nil
    end

  end

end