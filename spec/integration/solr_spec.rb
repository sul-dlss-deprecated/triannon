require 'spec_helper'

describe "integration tests for Solr", :vcr do

  before(:all) do
    @root_container = 'solr_integration_specs'
    vcr_cassette_name = "integration_tests_for_Solr/before_spec"
    create_root_container(@root_container, vcr_cassette_name)
    @ldp_testing_container_urls = []
    @solr_doc_ids = [] # without root container prefix
  end
  after(:all) do
    @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"
    vcr_cassette_name = "integration_tests_for_Solr/after_spec"
    delete_test_objects(@ldp_testing_container_urls, @solr_doc_ids, @root_container, vcr_cassette_name)
  end

  let(:write_anno) { Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix content: <http://www.w3.org/2011/content#> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <> a openannotation:Annotation;
       openannotation:hasBody [
         a content:ContentAsText,
           dcmitype:Text;
         content:chars \"Solr integration test\"
       ];
       openannotation:hasTarget <http://example.com/solr-integration-test>;
       openannotation:motivatedBy openannotation:commenting .")
  }

  context 'writes to Solr' do
    it "all fields in Solr doc" do
      write_solr_hash = Triannon::SolrWriter.solr_hash(write_anno.graph, @root_container)
      expect(write_solr_hash.size).to be > 6
      expect(write_solr_hash).to include(root: @root_container)
      id = write_anno.save
      anno_id = "#{@root_container}/#{id}"
      sleep(1) # give solr time to commit

      rsolr_client = RSolr.connect(:url => spec_solr_url)
      solr_resp = rsolr_client.get 'doc', :params => {:id => anno_id}
      expect(solr_resp["response"]["numFound"]).to eq 1
      solr_doc = solr_resp["response"]["docs"].first
      expect(solr_doc["id"]).to eq anno_id
      expect(Time.parse(solr_doc["timestamp"])).to be_a Time
      # all fields in orig solr_hash are stored fields and will be in solr response
      write_solr_hash.each_pair { |k,v|
        # :id isn't set before, which is also a factor in :anno_jsonld value
        expect(solr_doc[k.to_s]).to eq v unless (k == :id || k == :anno_jsonld || v.blank?)
      }
      @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}/#{anno_id}"
      @solr_doc_ids << id
    end
    it "has non-empty id value for outer node of anno_jsonld" do
      id = write_anno.save
      anno_id = "#{@root_container}/#{id}"
      sleep(1) # give solr time to commit

      rsolr_client = RSolr.connect(:url => spec_solr_url)
      solr_resp = rsolr_client.get 'doc', :params => {:id => anno_id}
      solr_doc = solr_resp["response"]["docs"].first
      expect(solr_doc["anno_jsonld"]).not_to match "@id\":\"\""
      expect(solr_doc["anno_jsonld"]).to match "@id\":\".+\""
      @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}/#{anno_id}"
      @solr_doc_ids << id
    end
  end

  it 'deletes from Solr' do
    id = write_anno.save
    anno_id = "#{@root_container}/#{id}"
    sleep(1) # give solr time to commit

    # ensure write succeeded
    rsolr_client = RSolr.connect(:url => spec_solr_url)
    solr_resp = rsolr_client.get 'doc', :params => {:id => anno_id}
    expect(solr_resp["response"]["numFound"]).to eq 1

    write_anno.destroy
    sleep(3) # SolrWriter add has commitWithin set to 500 ms; solrconfig has autocommit set to 3 sec
    rsolr_client = RSolr.connect(:url => spec_solr_url)
    solr_resp = rsolr_client.get 'doc', :params => {:id => anno_id}
    expect(solr_resp["response"]["numFound"]).to eq 0

    @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}/#{anno_id}"
  end

end
