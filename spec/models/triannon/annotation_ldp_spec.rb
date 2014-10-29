require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Triannon::AnnotationLdp do

  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:anno) { Triannon::AnnotationLdp.new }

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

  describe "#body_uris" do
    it 'returns an Array of body object ids as URIs - one body' do
      anno.load_data_into_graph anno_ttl
      expect(anno.body_uris.class).to eql Array
      expect(anno.body_uris.size).to eq 1
      body_uri = anno.body_uris.first
      expect(body_uri.class).to eql RDF::URI
      expect(body_uri.path).to match "#{anno.base_uri.path}/b/e14b93b7-3a88-4eb5-9688-7dea7f482d23"
    end
    it 'returns an Array of body object ids as URIs - 2 bodies' do
      body_url1 = "http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2/b/14788e2d-fe2a-424b-89b3-f73e77d81c62"
      body_url2 = "http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2/b/b20b2bd7-bbfa-4209-997c-e21ad8032e28"
      anno.load_data_into_graph "
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      <http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2> a openannotation:Annotation;
         openannotation:motivatedBy openannotation:commenting;
      	 openannotation:hasBody <#{body_url1}>,
      	    <#{body_url2}> .
      "
      expect(anno.body_uris.class).to eql Array
      expect(anno.body_uris.size).to eq 2
      expect(anno.body_uris).to include RDF::URI.new(body_url1)
      expect(anno.body_uris).to include RDF::URI.new(body_url2)
    end
    it "body object URIs are LDP resources stored in the annotation's body container" do
      anno.load_data_into_graph anno_ttl
      expect(anno.body_uris.first.path).to match "#{anno.base_uri.path}\/b\/.+"
    end
    it 'returns empty Array if there are no bodies' do
      anno.load_data_into_graph "
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      <http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Annotation;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2>;
         openannotation:motivatedBy openannotation:bookmarking .
      "
      expect(anno.body_uris).to eql []
    end
  end

  describe "#target_uris" do
    it 'returns an Array of target object ids as URIs - one target' do
      anno.load_data_into_graph anno_ttl
      expect(anno.target_uris.class).to eql Array
      expect(anno.target_uris.size).to eq 1
      target_uri = anno.target_uris.first
      expect(target_uri.class).to eql RDF::URI
      expect(target_uri.path).to match "#{anno.base_uri.path}/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1"
    end
    it 'returns an Array of target object ids as URIs - 2 targets' do
      target_url1 = "http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2/t/14788e2d-fe2a-424b-89b3-f73e77d81c62"
      target_url2 = "http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2/t/b20b2bd7-bbfa-4209-997c-e21ad8032e28"
      anno.load_data_into_graph "
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      <http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2> a openannotation:Annotation;
         openannotation:motivatedBy openannotation:commenting;
      	 openannotation:hasTarget <#{target_url1}>,
      	    <#{target_url2}> .
      "
      expect(anno.target_uris.class).to eql Array
      expect(anno.target_uris.size).to eq 2
      expect(anno.target_uris).to include RDF::URI.new(target_url1)
      expect(anno.target_uris).to include RDF::URI.new(target_url2)
    end
    it "target object URIs are LDP resources stored in the annotation's target container" do
      anno.load_data_into_graph anno_ttl
      expect(anno.target_uris.first.path).to match "#{anno.base_uri.path}\/t\/.+"
    end
    it 'returns empty Array if there are no targets' do
      anno.load_data_into_graph "
      @prefix ldp: <http://www.w3.org/ns/ldp#> .
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      <http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2> a ldp:Container,
           ldp:DirectContainer,
           ldp:RDFSource,
           openannotation:Annotation;
         ldp:hasMemberRelation ldp:member;
         ldp:membershipResource <http://localhost:8983/fedora/rest/anno/b5b5889b-d7f9-4c04-8117-2571bd42a3d2>;
         openannotation:motivatedBy openannotation:bookmarking .
      "
      expect(anno.target_uris).to eql []
    end
  end

  describe "#load_data_into_graph" do
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
  
  describe '#stripped_graph' do
    it 'has no ldp triples' do
      anno.load_data_into_graph anno_ttl
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
      anno.load_data_into_graph anno_ttl
      result = anno.graph.query [nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#resource")]
      expect(result.size).to eql 1
      result = anno.graph.query [nil, RDF.type, RDF::URI.new("http://www.jcp.org/jcr/nt/1.0base")]
      expect(result.size).to eql 1
      result = anno.graph.query [nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#lastModifiedBy"), nil]
      expect(result.size).to eql 1
      result = anno.graph.query [nil, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#writable"), nil]
      expect(result.size).to eql 1
      result = anno.graph.query [RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml"), nil, nil]
      expect(result.size).to eql 1
      result = anno.graph.query [nil, nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml")]
      expect(result.size).to eql 1

      stripped_graph = anno.stripped_graph
      result = stripped_graph.query [nil, RDF.type, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#resource")]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, RDF.type, RDF::URI.new("http://www.jcp.org/jcr/nt/1.0base")]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#lastModifiedBy"), nil]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, RDF::URI.new("http://fedora.info/definitions/v4/rest-api#writable"), nil]
      expect(result.size).to eql 0
      result = stripped_graph.query [RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml"), nil, nil]
      expect(result.size).to eql 0
      result = stripped_graph.query [nil, nil, RDF::URI.new("http://fedora.info/definitions/v4/repository#jcr/xml")]
      expect(result.size).to eql 0
    end
    it 'has open anno triples' do
      anno.load_data_into_graph anno_ttl
      stripped_graph = anno.stripped_graph
      result = stripped_graph.query [nil, RDF.type, RDF::OpenAnnotation.Annotation]
      expect(result.size).to eql 1
    end
  end

end