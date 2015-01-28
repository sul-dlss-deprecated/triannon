require 'spec_helper'

describe Triannon::SolrWriter, :vcr do
  context '#initialize' do
    it "sets up Rsolr client with solr_url from Triannon.yml" do
      expect(RSolr).to receive(:connect).with(:url => Triannon.config[:solr_url])
      Triannon::SolrWriter.new
    end
  end
  
  let(:rsolr_client) {RSolr.connect(:url => Triannon.config[:solr_url])}
  let(:solr_writer) {
    allow(Triannon::SolrWriter.new).to receive("@client").and_return(rsolr_client)
    Triannon::SolrWriter.new
  }
  context '#add' do
    it "calls RSolr::Client.add with hash and commitWithin=500" do      
      doc_hash = {:id => '666'}
      expect_any_instance_of(RSolr::Client).to receive(:add).with(doc_hash, :add_attributes => {:commitWithin=> 500})
      solr_writer.add(doc_hash)
    end
    it "uses with_retries" do
      doc_hash = {:id => '666'}
      expect(solr_writer).to receive(:with_retries)
      solr_writer.add(doc_hash)
    end
  end
  
  context '#delete' do
    it "calls RSolr::Client.delete_by_id" do
      allow_any_instance_of(RSolr::Client).to receive(:commit)
      expect_any_instance_of(RSolr::Client).to receive(:delete_by_id).with("foo")
      solr_writer.delete("foo")
    end
    it "calls RSolr::Client.commit" do
      allow_any_instance_of(RSolr::Client).to receive(:delete_by_id)
      expect_any_instance_of(RSolr::Client).to receive(:commit)
      solr_writer.delete("foo")
    end
    it "uses with_retries" do
      expect(solr_writer).to receive(:with_retries)
      solr_writer.delete("foo")
    end
  end
end