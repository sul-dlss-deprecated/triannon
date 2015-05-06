require 'spec_helper'

describe OA::Graph do

  let(:anno_ttl) { Triannon.annotation_fixture('/../ldp_annotations/fcrepo4_base.ttl') }

  describe '#remove_ldp_triples' do
    it 'graph returned has no ldp triples' do
      graph = RDF::Graph.new.from_ttl anno_ttl
      expect(graph.count).to eql 30
      expect(graph.query([nil, RDF.type, RDF::Vocab::LDP.Container]).size).to eql 1
      expect(graph.query([nil, RDF.type, RDF::Vocab::LDP.RDFSource]).size).to eql 1
      expect(graph.query([nil, RDF::Vocab::LDP.contains, nil]).size).to eql 2

      stripped_graph = OA::Graph.remove_ldp_triples graph
      expect(stripped_graph.count).to eql 26
      expect(stripped_graph.query([nil, RDF.type, RDF::Vocab::LDP.Container]).size).to eql 0
      expect(stripped_graph.query([nil, RDF.type, RDF::Vocab::LDP.RDFSource]).size).to eql 0
      expect(stripped_graph.query([nil, RDF::Vocab::LDP.contains, nil]).size).to eql 0
    end
  end

  describe '#remove_fedora_triples' do
    it 'graph returned has no fedora triples' do
      graph = RDF::Graph.new.from_ttl anno_ttl
      expect(graph.size).to eql 30
      expect(graph.query([nil, RDF.type, RDF::Vocab::Fcrepo4.Resource]).size).to eql 1
      expect(graph.query([nil, RDF.type, RDF::URI.new("http://www.jcp.org/jcr/nt/1.0base")]).size).to eql 1
      expect(graph.query([nil, RDF::Vocab::Fcrepo4.lastModifiedBy, nil]).size).to eql 1
      expect(graph.query([nil, RDF::Vocab::Fcrepo4.writable, nil]).size).to eql 1
      expect(graph.query([RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml"), nil, nil]).size).to eql 1
      expect(graph.query([nil, nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml")]).size).to eql 1

      stripped_graph = OA::Graph.remove_fedora_triples graph
      expect(stripped_graph.size).to eql 8
      expect(stripped_graph.query([nil, RDF.type, RDF::Vocab::Fcrepo4.Resource]).size).to eql 0
      expect(stripped_graph.query([nil, RDF.type, RDF::URI.new("http://www.jcp.org/jcr/nt/1.0base")]).size).to eql 0
      expect(stripped_graph.query([nil, RDF::Vocab::Fcrepo4.lastModifiedBy, nil]).size).to eql 0
      expect(stripped_graph.query([nil, RDF::Vocab::Fcrepo4.writable, nil]).size).to eql 0
      expect(stripped_graph.query([RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml"), nil, nil]).size).to eql 0
      expect(stripped_graph.query([nil, nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml")]).size).to eql 0
    end

    it "graph returned doesn't have type http://purl.org/dc/elements/1.1/describable" do
      g = RDF::Graph.new.from_ttl(anno_ttl)
      # this predates Fedora 4.1.1
      #expect(g.query([nil, RDF.type, RDF::URI.new("http://purl.org/dc/elements/1.1/describable")]).size).to eql 1
      expect(g.query([nil, RDF.type, RDF::URI.new("http://purl.org/dc/elements/1.1/describable")]).size).to eql 0
      stripped_graph = OA::Graph.remove_fedora_triples g
      expect(stripped_graph.query([nil, RDF.type, RDF::URI.new("http://purl.org/dc/elements/1.1/describable")]).size).to eql 0
    end

    it "graph returned doesn't have type http://fedora.info/definitions/v4/rest-api#DublinCoreDescribable" do
      g = RDF::Graph.new.from_ttl(Triannon.annotation_fixture('/../ldp_annotations/fcrepo4_body.ttl'))
      # this predates Fedora 4.1.1
      #expect(g.query([nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#DublinCoreDescribable")]).size).to eql 1
      expect(g.query([nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#DublinCoreDescribable")]).size).to eql 0
      stripped_graph = OA::Graph.remove_fedora_triples g
      expect(stripped_graph.query([nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#DublinCoreDescribable")]).size).to eql 0
    end
  end

end
