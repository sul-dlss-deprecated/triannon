require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

vcr_options = {:re_record_interval => 45.days}  # TODO will make shorter once we have jetty running fedora4
describe Triannon::LdpCreator, :vcr => vcr_options do

  let(:anno) {
    Triannon::Annotation.new data: Triannon.annotation_fixture("body-chars.ttl")
  }
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

end