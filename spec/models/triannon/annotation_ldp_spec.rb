require 'spec_helper'

describe Triannon::AnnotationLdp, :vcr do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:root_container) {'specs'}
  let(:root_container_url) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}/#{root_container}"}
  let(:anno) { Triannon::AnnotationLdp.new }

  describe "#graph" do
    it "creates an RDF::Graph if it does not yet exist" do
      g = anno.graph
      expect(g.count).to eq 0
    end
  end

  describe "#base_uri" do
    it "returns the URI to the annotation's main root-level subject" do
      anno.load_statements_into_graph base_stmts
      expect(anno.base_uri.path).to match %r{/67/c0/18/9d/67c0189d-56d4-47fb-abea-1f995187b358$}
    end
  end

  describe "#body_uris" do
    it 'returns an Array of body object ids as URIs - one body' do
      anno.load_statements_into_graph base_stmts
      expect(anno.body_uris.class).to eql Array
      expect(anno.body_uris.size).to eq 1
      body_uri = anno.body_uris.first
      expect(body_uri.class).to eql RDF::URI
      expect(body_uri.path).to match "#{anno.base_uri.path}/b/67/f2/30/a2/67f230a2-3bf3-41e5-952e-8362dc7a5366"
    end
    it 'returns an Array of body object ids as URIs - 2 bodies' do
      body_url1 = "#{root_container_url}/a6/42/73/68/a6427368-4358-444c-80fc-10587f24c94b/b/e1/89/b9/e1/e189b9e1-4e83-4549-aa48-ac0b4dd6bf0c"
      body_url2 = "#{root_container_url}/a6/42/73/68/a6427368-4358-444c-80fc-10587f24c94b/b/93/b2/66/39/93b26639-b0ba-43c7-954e-ecd800332bec"
      stmts = RDF::Turtle::Reader.new("
        @prefix oa: <http://www.w3.org/ns/oa#> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        <#{root_container_url}/a6/42/73/68/a6427368-4358-444c-80fc-10587f24c94b> a oa:Annotation;
           oa:motivatedBy oa:commenting;
           oa:hasBody <#{body_url1}>,
             <#{body_url2}> .
      ").statements.to_a
      anno.load_statements_into_graph stmts
      expect(anno.body_uris.class).to eql Array
      expect(anno.body_uris.size).to eq 2
      expect(anno.body_uris).to include RDF::URI.new(body_url1)
      expect(anno.body_uris).to include RDF::URI.new(body_url2)
    end
    it "body object URIs are LDP resources stored in the annotation's body container" do
      anno.load_statements_into_graph base_stmts
      expect(anno.body_uris.first.path).to match "#{anno.base_uri.path}\/b\/.+"
    end
    it 'returns empty Array if there are no bodies' do
      stmts = RDF::Turtle::Reader.new("
        @prefix ldp: <http://www.w3.org/ns/ldp#> .
        @prefix oa: <http://www.w3.org/ns/oa#> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        <#{root_container_url}/a6/42/73/68/a6427368-4358-444c-80fc-10587f24c94b> a ldp:Container,
             ldp:BasicContainer,
             ldp:RDFSource,
             oa:Annotation;
           oa:motivatedBy oa:bookmarking .
      ").statements.to_a
      anno.load_statements_into_graph stmts
      expect(anno.body_uris).to eql []
    end
  end

  describe "#target_uris" do
    it 'returns an Array of target object ids as URIs - one target' do
      anno.load_statements_into_graph base_stmts
      expect(anno.target_uris.class).to eql Array
      expect(anno.target_uris.size).to eq 1
      target_uri = anno.target_uris.first
      expect(target_uri.class).to eql RDF::URI
      expect(target_uri.path).to match "#{anno.base_uri.path}/t/0a/b5/36/9d/0ab5369d-f872-4488-8f1e-3143819b94bf"
    end
    it 'returns an Array of target object ids as URIs - 2 targets' do
      target_url1 = "#{root_container_url}/a6/42/73/68/a6427368-4358-444c-80fc-10587f24c94b/t/e1/89/b9/e1/e189b9e1-4e83-4549-aa48-ac0b4dd6bf0c"
      target_url2 = "#{root_container_url}/a6/42/73/68/a6427368-4358-444c-80fc-10587f24c94b/t/93/b2/66/39/93b26639-b0ba-43c7-954e-ecd800332bec"
      stmts = RDF::Turtle::Reader.new("
        @prefix oa: <http://www.w3.org/ns/oa#> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        <#{root_container_url}/a6/42/73/68/a6427368-4358-444c-80fc-10587f24c94b> a oa:Annotation;
           oa:motivatedBy oa:commenting;
           oa:hasTarget <#{target_url1}>,
              <#{target_url2}> .
      ").statements.to_a
      anno.load_statements_into_graph stmts
      expect(anno.target_uris.class).to eql Array
      expect(anno.target_uris.size).to eq 2
      expect(anno.target_uris).to include RDF::URI.new(target_url1)
      expect(anno.target_uris).to include RDF::URI.new(target_url2)
    end
    it "target object URIs are LDP resources stored in the annotation's target container" do
      anno.load_statements_into_graph base_stmts
      expect(anno.target_uris.first.path).to match "#{anno.base_uri.path}\/t\/.+"
    end
    it 'returns empty Array if there are no targets' do
      stmts = RDF::Turtle::Reader.new("
        @prefix ldp: <http://www.w3.org/ns/ldp#> .
        @prefix oa: <http://www.w3.org/ns/oa#> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        <#{root_container_url}/a6/42/73/68/a6427368-4358-444c-80fc-10587f24c94b> a ldp:Container,
             ldp:BasicContainer,
             ldp:RDFSource,
             oa:Annotation;
           oa:motivatedBy oa:bookmarking .
      ").statements.to_a
      anno.load_statements_into_graph stmts
      expect(anno.target_uris).to eql []
    end
  end

  describe '#load_statements_into_graph' do
    it 'loads passed statements to graph' do
      stmts = RDF::Graph.new.from_ttl(anno_ttl).statements
      anno.load_statements_into_graph stmts
      solns = anno.graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(solns.size).to eq 1
      expect(solns.first.subject.path).to match %r{/67/c0/18/9d/67c0189d-56d4-47fb-abea-1f995187b358$}
    end
    it 'adds statements to existing graph' do
      stmts = RDF::Graph.new.from_ttl(anno_ttl).statements
      anno.load_statements_into_graph stmts
      base_graph_size = anno.graph.size
      body_ttl =  File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl')
      anno.load_statements_into_graph RDF::Graph.new.from_ttl(body_ttl).statements
      expect(anno.graph.size).to be > base_graph_size
    end
    it 'handles empty Array argument' do
      anno.load_statements_into_graph []
      expect(anno.graph.size).to eq 0
    end
    it 'handles nil argument' do
      anno.load_statements_into_graph nil
      expect(anno.graph.size).to eq 0
    end
  end

  describe '#stripped_graph' do
    it 'has no ldp triples' do
      anno.load_statements_into_graph base_stmts
      result = anno.graph.query [nil, RDF.type, RDF::URI.new("http://www.w3.org/ns/ldp#Container")]
      expect(result.first.subject.to_s).to eql anno.base_uri.to_s
      result = anno.graph.query [nil, RDF::URI.new("http://www.w3.org/ns/ldp#contains"), nil]
      expect(result.size).to eql 2

      stripped_graph = anno.stripped_graph
      result = stripped_graph.query [nil, RDF.type, RDF::URI.new("http://www.w3.org/ns/ldp#Container")]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, RDF::URI.new("http://www.w3.org/ns/ldp#contains"), nil]
      expect(result.size).to eql 0
    end
    it 'has no fedora triples' do
      anno.load_statements_into_graph base_stmts
      result = anno.graph.query [nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/repository#Resource")]
      expect(result.size).to eql 1
      result = anno.graph.query [nil, RDF.type, RDF::URI.new("http://www.jcp.org/jcr/nt/1.0base")]
      expect(result.size).to eql 1
      result = anno.graph.query [nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#lastModifiedBy"), nil]
      expect(result.size).to eql 1
      result = anno.graph.query [nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#writable"), nil]
      expect(result.size).to eql 1
      result = anno.graph.query [RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml"), nil, nil]
      expect(result.size).to eql 1
      result = anno.graph.query [nil, nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml")]
      expect(result.size).to eql 1

      stripped_graph = anno.stripped_graph
      result = stripped_graph.query [nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/repository#Resource")]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, RDF.type, RDF::URI.new("http://www.jcp.org/jcr/nt/1.0base")]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#lastModifiedBy"), nil]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#writable"), nil]
      expect(result.size).to eql 0
      result = stripped_graph.query [RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml"), nil, nil]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml")]
      expect(result.size).to eql 0
    end
    it 'has open anno triples' do
      anno.load_statements_into_graph base_stmts
      stripped_graph = anno.stripped_graph
      result = stripped_graph.query [nil, RDF.type, RDF::Vocab::OA.Annotation]
      expect(result.size).to eql 1
    end
  end

end
