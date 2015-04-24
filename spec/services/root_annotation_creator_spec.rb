require 'spec_helper'

describe Triannon::RootAnnotationCreator, :vcr do

  describe "#create" do
    let(:dummy_url) { 'http://localhost:8983/fedora/rest/bork' }
    let(:tombstone_url) { dummy_url + '/fcr:tombstone'}
    let(:conn) { Faraday.new :url => dummy_url  }

    def delete_root
      conn.delete
      Faraday.new(:url => tombstone_url).delete
    end

    before(:each) do
       config = { :ldp_url =>  dummy_url }
       allow(Triannon).to receive(:config).and_return(config)
       delete_root
    end

    after(:each) { delete_root }

    it "creates the root annotations container if it does not already exist" do
      expect(STDOUT).to receive(:puts).with("Created root annotation container #{dummy_url}")
      expect(Triannon::RootAnnotationCreator.create).to eq true

      resp = conn.get do |req|
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.status).to eq 200

      uri = RDF::URI.new Triannon.config[:ldp_url]
      g = RDF::Graph.new
      g.from_ttl resp.body
      q = RDF::Query.new
      q << [uri, RDF.type, RDF::Vocab::LDP.Container]
      soln = g.query q
      expect(soln.size).to eq 1
    end

    it "does not do anything if the root annotations container already exists" do
      expect(STDOUT).to receive(:puts).with("Created root annotation container #{dummy_url}")
      expect(Triannon::RootAnnotationCreator.create).to eq true
      expect(STDOUT).to receive(:puts).with("Root annotation resource already exists.")
      expect(Triannon::RootAnnotationCreator.create).to eq false

      resp = conn.get
      expect(resp.status).to eq 200
    end
  end
end
