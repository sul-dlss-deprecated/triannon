require 'spec_helper'

describe Triannon::LdpLoader do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:root_anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_root_anno_container.ttl') }

  describe '*load' do
    it "returns a graph of an OpenAnnotation without LDP or FCrepo triples" do
      allow_any_instance_of(Triannon::LdpLoader).to receive(:get_ttl).and_return(anno_ttl, body_ttl, target_ttl)
      result = Triannon::LdpLoader.load('somekey')
      expect(result).to be_an_instance_of(RDF::Graph)
      root_node_solns = result.query [nil, RDF.type, RDF::OpenAnnotation.Annotation]
      expect(root_node_solns.count).to eql 1
      root_node = root_node_solns.first.subject
      # no LDP
      expect(result.query([nil, RDF.type, RDF::URI("http://www.w3.org/ns/ldp#Container")]).size).to eql 0
      # no FCrepo
      expect(result.query([nil, RDF::FCRepo4.created, nil]).size).to eql 0
    end
    it "calls #load_anno_container, #load_bodies and #load_targets" do
      expect_any_instance_of(Triannon::LdpLoader).to receive(:load_anno_container)
      expect_any_instance_of(Triannon::LdpLoader).to receive(:load_bodies)
      expect_any_instance_of(Triannon::LdpLoader).to receive(:load_targets)
      Triannon::LdpLoader.load('somekey')
    end
    it "calls LdpToOAMapper.ldp_to_oa" do
      allow_any_instance_of(Triannon::LdpLoader).to receive(:load_anno_container)
      allow_any_instance_of(Triannon::LdpLoader).to receive(:load_bodies)
      allow_any_instance_of(Triannon::LdpLoader).to receive(:load_targets)
      expect(Triannon::LdpToOaMapper).to receive(:ldp_to_oa).with(instance_of(Triannon::AnnotationLdp))
      Triannon::LdpLoader.load('somekey')
    end
  end

  describe "#load_anno_container" do
    it "asks the ldp store for the annotation object" do
      loader = Triannon::LdpLoader.new 'somekey'
      expect(loader).to receive(:get_ttl).with("somekey")
      loader.load_anno_container
    end
    it "calls AnnotationLdp.load_statements_into_graph for stored anno object" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).with("somekey").and_return(anno_ttl)
      expect(loader.ldp_annotation).to receive(:load_statements_into_graph)
      loader.load_anno_container
    end
    it "removes Fedora triples before calling AnnotationLdp.load_statements_into_graph" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).with("somekey").and_return(anno_ttl)
      expect(RDF::FCRepo4).to receive(:remove_fedora_triples).and_return(RDF::Graph.new)
      expect(loader.ldp_annotation).to receive(:load_statements_into_graph)
      loader.load_anno_container
    end
    it "graph triples include annotatedAt triple from stored anno object" do
      loader = Triannon::LdpLoader.new 'somekey'
      prov_ttl = File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base_prov.ttl')
      allow(loader).to receive(:get_ttl).with("somekey").and_return(prov_ttl)
      loader.load_anno_container
      result = loader.ldp_annotation.graph.query [nil, RDF::OpenAnnotation.annotatedAt, nil]
      expect(result.size).to eq 1
    end
    it "no triple in the graph has the (ldp store) body uri as a subject (before #load_bodies is called)" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).with("somekey").and_return(anno_ttl)
      loader.load_anno_container
      body_uri = loader.ldp_annotation.body_uris.first
      result = loader.ldp_annotation.graph.query [body_uri, nil, nil]
      expect(result.size).to eq 0
    end
    it "no triple in the graph has the (ldp store) target uri as a subject (before #load_targets is called)" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:get_ttl).with("somekey").and_return(anno_ttl)
      loader.load_anno_container
      target_uri = loader.ldp_annotation.target_uris.first
      result = loader.ldp_annotation.graph.query [target_uri, nil, nil]
      expect(result.size).to eq 0
    end
  end

  describe "#load_bodies" do
    it "asks the ldp store for each subject of hasBody" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader.ldp_annotation).to receive(:body_uris).and_return(["body_key1", "body_key2"])
      expect(loader).to receive(:get_ttl).with("body_key1").and_return(body_ttl)
      expect(loader).to receive(:get_ttl).with("body_key2")
      loader.load_bodies
    end
    it "calls AnnotationLdp.load_statements_into_graph for each stored body object" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader.ldp_annotation).to receive(:body_uris).and_return(["body_key1", "body_key2"])
      allow(loader).to receive(:get_ttl).with("body_key1").and_return(body_ttl)
      allow(loader).to receive(:get_ttl).with("body_key2").and_return(body_ttl)
      expect(loader.ldp_annotation).to receive(:load_statements_into_graph).twice
      loader.load_bodies
    end
    it "removes Fedora triples before calling AnnotationLdp.load_statements_into_graph" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader.ldp_annotation).to receive(:body_uris).and_return(["some_body_key"])
      allow(loader).to receive(:get_ttl).with("some_body_key").and_return(body_ttl)
      expect(RDF::FCRepo4).to receive(:remove_fedora_triples).and_return(RDF::Graph.new)
      expect(loader.ldp_annotation).to receive(:load_statements_into_graph)
      loader.load_bodies
    end
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
    it "asks the ldp store for each subject of hasTarget" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader.ldp_annotation).to receive(:target_uris).and_return(["target_key1", "target_key2"])
      expect(loader).to receive(:get_ttl).with("target_key1").and_return(target_ttl)
      expect(loader).to receive(:get_ttl).with("target_key2")
      loader.load_targets
    end
    it "calls AnnotationLdp.load_statements_into_graph for each stored target object" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader.ldp_annotation).to receive(:target_uris).and_return(["target_key1", "target_key2"])
      expect(loader).to receive(:get_ttl).with("target_key1").and_return(target_ttl)
      expect(loader).to receive(:get_ttl).with("target_key2").and_return(target_ttl)
      expect(loader.ldp_annotation).to receive(:load_statements_into_graph).twice
      loader.load_targets
    end
    it "removes Fedora triples before calling AnnotationLdp.load_statements_into_graph" do
      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader.ldp_annotation).to receive(:target_uris).and_return(["some_target_key"])
      allow(loader).to receive(:get_ttl).with("some_target_key").and_return(body_ttl)
      expect(RDF::FCRepo4).to receive(:remove_fedora_triples).and_return(RDF::Graph.new)
      expect(loader.ldp_annotation).to receive(:load_statements_into_graph)
      loader.load_targets
    end
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

  describe '#get_ttl' do
    it "retrieves data via HTTP over LdpLoader.conn when given an id" do
      # TODO brittle since it stubs the whole http interaction
      resp = double()
      allow(resp).to receive(:body)
      conn = double()
      allow(conn).to receive(:get).and_return(resp)

      loader = Triannon::LdpLoader.new 'somekey'
      allow(loader).to receive(:conn).and_return(conn)

      loader.send(:get_ttl, "id")
    end
  end

end