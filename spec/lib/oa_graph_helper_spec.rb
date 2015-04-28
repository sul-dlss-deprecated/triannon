require 'spec_helper'

describe OA::Graph do

  let(:anno_ttl) { Triannon.annotation_fixture('/../ldp_annotations/open_anno_ldp_container.ttl') }

  describe '#remove_ldp_triples' do
    it 'graph returned has no ldp triples' do
      graph = RDF::Graph.new
      graph.from_ttl anno_ttl
      expect(graph.count).to eql 39
      result = graph.query [nil, RDF.type, RDF::URI.new("http://www.w3.org/ns/ldp#Container")]
      expect(result.size).to eql 1
      result = graph.query [nil, RDF::URI.new("http://www.w3.org/ns/ldp#contains"), nil]
      expect(result.size).to eql 2

      stripped_graph = OA::Graph.remove_ldp_triples graph
      expect(stripped_graph.count).to eql 29
      result = stripped_graph.query [nil, RDF.type, RDF::URI.new("http://www.w3.org/ns/ldp#Container")]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, RDF::URI.new("http://www.w3.org/ns/ldp#contains"), nil]
      expect(result.size).to eql 0
    end
  end

  describe '#remove_fedora_triples' do
    it 'graph returned has no fedora triples' do
      graph = RDF::Graph.new.from_ttl anno_ttl
      expect(graph.size).to eql 39
      expect(graph.query([nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#resource")]).size).to eql 1
      expect(graph.query([nil, RDF.type, RDF::URI.new("http://www.jcp.org/jcr/nt/1.0base")]).size).to eql 1
      expect(graph.query([nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#lastModifiedBy"), nil]).size).to eql 1
      expect(graph.query([nil, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#writable"), nil]).size).to eql 1
      expect(graph.query([RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml"), nil, nil]).size).to eql 1
      expect(graph.query([nil, nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml")]).size).to eql 1

      stripped_graph = OA::Graph.remove_fedora_triples graph
      expect(stripped_graph.size).to eql 14
      expect(stripped_graph.query([nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#resource")]).size).to eql 0
      expect(stripped_graph.query([nil, RDF.type, RDF::URI.new("http://www.jcp.org/jcr/nt/1.0base")]).size).to eql 0
      expect(stripped_graph.query([nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#lastModifiedBy"), nil]).size).to eql 0
      expect(stripped_graph.query([nil, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#writable"), nil]).size).to eql 0
      expect(stripped_graph.query([RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml"), nil, nil]).size).to eql 0
      expect(stripped_graph.query([nil, nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml")]).size).to eql 0
    end

    it "graph returned doesn't have type http://purl.org/dc/elements/1.1/describable" do
      g = RDF::Graph.new.from_ttl(anno_ttl)
      expect(g.query([nil, RDF.type, RDF::URI.new("http://purl.org/dc/elements/1.1/describable")]).size).to eql 1
      stripped_graph = OA::Graph.remove_fedora_triples g
      expect(stripped_graph.query([nil, RDF.type, RDF::URI.new("http://purl.org/dc/elements/1.1/describable")]).size).to eql 0
    end

    it "graph returned doesn't have type http://fedora.info/definitions/v4/rest-api#DublinCoreDescribable" do
      g = RDF::Graph.new.from_ttl(Triannon.annotation_fixture('/../ldp_annotations/anno_body_ldp_container.ttl'))
      expect(g.query([nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#DublinCoreDescribable")]).size).to eql 1
      stripped_graph = OA::Graph.remove_fedora_triples g
      expect(stripped_graph.query([nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#DublinCoreDescribable")]).size).to eql 0
    end
  end

end
