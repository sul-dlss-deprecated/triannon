require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

vcr_options = {:re_record_interval => 45.days}  # TODO will make shorter once we have jetty running fedora4
describe Triannon::LdpCreator, :vcr => vcr_options do

  let(:anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("body-chars.ttl") }
  let(:svc) { Triannon::LdpCreator.new anno }
  let(:conn) { Faraday.new(:url => Triannon.config[:ldp_url]) }

  describe "#create" do
    it "POSTS a ttl represntation of the Annotation to the correct LDP container" do
      new_pid = svc.create

      resp = conn.get do |req|
        req.url " #{new_pid}"
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.body).to match /oa#commenting/
    end
  end

  describe "#create_body_container" do
    it "POSTS a ttl represntation of an LDP directContainer to the newly created Annotation" do
      new_pid = svc.create
      svc.create_body_container

      resp = conn.get do |req|
        req.url " #{new_pid}/b"
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.body).to match /oa#hasBody/
      expect(resp.body).to match /#{new_pid}/
      # fails now hasMemberRelation <http://www.w3.org/ns/ldp#hasMemberRelation> <http://fedora.info/definitions/v4/repository#hasChild>
    end
  end

  describe "#create_target_container" do
    it "POSTS a ttl represntation of an LDP directContainer to the newly created Annotation" do
      new_pid = svc.create
      svc.create_target_container

      resp = conn.get do |req|
        req.url " #{new_pid}/t"
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.body).to match /oa#hasTarget/
      expect(resp.body).to match /#{new_pid}/
    end
  end

  describe "#create_body" do
    it "POSTS a ttl represntation of a body to the body container" do
      new_pid = svc.create
      svc.create_body_container
      body_pid = svc.create_body

      resp = conn.get do |req|
        req.url " #{new_pid}/b/#{body_pid}"
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.body).to match /I love this/
      expect(resp.body).to match /#{new_pid}/
    end
  end

  describe "#create_target" do
    it "POSTS a ttl represntation of a target to the target container" do
      new_pid = svc.create
      svc.create_target_container
      target_pid = svc.create_target

      resp = conn.get do |req|
        req.url " #{new_pid}/t/#{target_pid}"
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.body).to match /purl.stanford.edu/
      expect(resp.body).to match /triannon.*\/externalReference/
    end
  end

  describe ".create" do
    it "creates an entire Annotation vi LDP and returns the pid" do
      id = Triannon::LdpCreator.create anno

      resp = conn.get do |req|
        req.url " #{id}"
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.body).to match /hasBody/
      expect(resp.body).to match /hasTarget/
    end
  end
  
  describe '#subject_statements' do
    it 'appropriate blank node statements when the subject is an RDF::Node in the graph' do
      # we know anno's graph has a body with a blank node
      has_body_stmts = anno.graph.query([nil, RDF::OpenAnnotation.hasBody, nil])
      expect(has_body_stmts.size).to eql 1
      body_resource = has_body_stmts.first.object
      expect(body_resource).to be_a RDF::Node
      
      body_stmts = svc.send(:subject_statements, body_resource, anno.graph)
      expect(body_stmts.size).to eql 3
      expect(body_stmts).to include([body_resource, RDF::Content::chars, "I love this!"])
      expect(body_stmts).to include([body_resource, RDF.type, RDF::Content.ContentAsText])
      expect(body_stmts).to include([body_resource, RDF.type, RDF::DCMIType.Text])
    end
    it 'should recurse when the object of a subject statement is a blank node' do
      graph = RDF::Graph.new
      graph.from_jsonld(Triannon.annotation_fixture("html-frag-pos-selector.json"))
      has_target_stmts = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      target_resource = has_target_stmts.first.object

      target_stmts = svc.send(:subject_statements, target_resource, graph)
      expect(target_stmts.size).to eql 6
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, "http://purl.stanford.edu/kq131cs7229.html"])
      has_selector_stmts = graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil])
      selector_resource = has_selector_stmts.first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource])
      expect(target_stmts).to include([selector_resource, RDF.type, RDF::OpenAnnotation.TextPositionSelector])
      expect(target_stmts).to include([selector_resource, RDF::OpenAnnotation.start, RDF::Literal.new(0)])
      expect(target_stmts).to include([selector_resource, RDF::OpenAnnotation.end, RDF::Literal.new(66)])
    end
    it 'empty Array when the subject is an RDF::Node not in the graph' do
      expect(svc.send(:subject_statements, RDF::Node.new, anno.graph)).to eql []
    end
    it 'empty Array when the subject is an RDF::URI' do
      # we know anno's graph has a target with a URI
      has_target_stmts = anno.graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      expect(has_target_stmts.size).to eql 1
      target_resource = has_target_stmts.first.object
      expect(target_resource).to be_a RDF::URI
      expect(svc.send(:subject_statements, target_resource, anno.graph)).to eql []
    end
    it 'empty Array when subject is not RDF::Node or RDF::URI' do
      expect(svc.send(:subject_statements, nil, anno.graph)).to eql []
    end
  end

end