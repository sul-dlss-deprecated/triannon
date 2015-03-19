require 'spec_helper'

describe Triannon::SolrSearcher, :vcr do
  context '#initialize' do
    it "sets up Rsolr client with solr_url from Triannon.yml" do
      expect(RSolr).to receive(:connect).with(:url => Triannon.config[:solr_url])
      Triannon::SolrSearcher.new
    end
  end

  let(:rsolr_client) {RSolr.connect(:url => Triannon.config[:solr_url])}
  let(:solr_searcher) {
    allow(Triannon::SolrSearcher.new).to receive("@client").and_return(rsolr_client)
    Triannon::SolrSearcher.new
  }

  context '#search' do
    it "calls RSolr::Client.post with params hash" do
      solr_params_hash = {:q => '666'}
      expect_any_instance_of(RSolr::Client).to receive(:post).with('select', {:params => solr_params_hash})
      solr_searcher.search solr_params_hash
    end
    it "returns a solr response object with docs with anno_jsonld field" do
      solr_response = solr_searcher.search({:fq => ["motivation:commenting"]})
      expect(solr_response).to be_a_kind_of RSolr::Response
      expect(solr_response).to match a_hash_including('response' => a_hash_including('docs'))
      expect(solr_response['response']['docs'].size).to be > 0
      solr_response['response']['docs'].each { |doc_hash|
        expect(doc_hash).to match a_hash_including('anno_jsonld')
      }
    end
    it "works with no params" do
      solr_response = solr_searcher.search
      expect(solr_response).to be_a_kind_of RSolr::Response
      expect(solr_response).to match a_hash_including('response' => a_hash_including('docs'))
      expect(solr_response['response']['docs'].size).to be > 0
      solr_response['response']['docs'].each { |doc_hash|
        expect(doc_hash).to match a_hash_including('anno_jsonld')
      }
    end
    it "uses with_retries" do
      expect(solr_searcher).to receive(:with_retries)
      solr_searcher.search({:q => '666'})
    end
  end

  context '.anno_graphs_array' do
    let(:solr_response) {
      { "responseHeader"=>{"status"=>0, "QTime"=>9, "params"=>{"fq"=>"motivation:commenting", "wt"=>"ruby"}}, 
        "response"=>{"numFound"=>3, "start"=>0, "maxScore"=>1.0,
          "docs"=>[
            {"id"=>"d3019689-d3ff-4290-8ee3-72fec2320332",
              "field1"=>["value1"],
              "anno_jsonld"=>"{\"@context\":\"http://www.w3.org/ns/oa-context-20130208.json\",\"@graph\":[{\"@id\":\"_:g70337046884060\",\"@type\":[\"dctypes:Text\",\"cnt:ContentAsText\"],\"chars\":\"I hate this!\"},{\"@id\":\"http://your.triannon-server.com/annotations/d3019689-d3ff-4290-8ee3-72fec2320332\",\"@type\":\"oa:Annotation\",\"hasBody\":\"_:g70337046884060\",\"hasTarget\":\"http://purl.stanford.edu/kq131cs7229\",\"motivatedBy\":\"oa:commenting\"}]}",
              "field2"=>["value2"]},
            {"id"=>"51558876-f6df-4da4-b268-02c8bff94391",
              "field1"=>["aaa"],
              "anno_jsonld"=>"{\"@context\":\"http://www.w3.org/ns/oa-context-20130208.json\",\"@graph\":[{\"@id\":\"_:g70337056969180\",\"@type\":[\"dctypes:Text\",\"cnt:ContentAsText\"],\"chars\":\"I love this!\"},{\"@id\":\"http://your.triannon-server.com/annotations/51558876-f6df-4da4-b268-02c8bff94391\",\"@type\":\"oa:Annotation\",\"hasBody\":\"_:g70337056969180\",\"hasTarget\":\"http://purl.stanford.edu/kq131cs7229\",\"motivatedBy\":\"oa:commenting\"}]}",
              "field2"=>["bbb"]},
            {"id"=>"5686cffa-14c1-4aa4-8cef-bf62e9f4ab82",
              "field1"=>["ccc"],
              "anno_jsonld"=>"{\"@context\":\"http://www.w3.org/ns/oa-context-20130208.json\",\"@graph\":[{\"@id\":\"_:g70252904268480\",\"@type\":[\"dctypes:Text\",\"cnt:ContentAsText\"],\"chars\":\"testing redirect 2\"},{\"@id\":\"http://your.triannon-server.com/annotations/5686cffa-14c1-4aa4-8cef-bf62e9f4ab82\",\"@type\":\"oa:Annotation\",\"hasBody\":\"_:g70252904268480\",\"hasTarget\":\"http://purl.stanford.edu/oo111oo2222\",\"motivatedBy\":\"oa:commenting\"}]}",
              "field2"=>["ddd"]}
          ]
          }
      }
    }
    let(:solr_docs) { solr_response['response']['docs'] }
    let(:result_array) { Triannon::SolrSearcher.anno_graphs_array(solr_response)}
    it "returns an Array of Triannon::Graph objects" do
      expect(result_array).to be_a Array
      result_array.each { |item|
        expect(item).to be_a Triannon::Graph
        expect(item.size).to be > 2
      }
    end
    it "properly parses the jsonld in anno_jsonld field from each Solr doc in the response" do
      expect(result_array[0].id_as_url).to match a_string_ending_with "d3019689-d3ff-4290-8ee3-72fec2320332"
      expect(result_array[0].body_chars).to eq ["I hate this!"]
      expect(result_array[0].predicate_urls(RDF::OpenAnnotation.hasTarget)).to eq ["http://purl.stanford.edu/kq131cs7229"]

      expect(result_array[1].id_as_url).to match a_string_ending_with "51558876-f6df-4da4-b268-02c8bff94391"
      expect(result_array[1].body_chars).to eq ["I love this!"]
      expect(result_array[1].predicate_urls(RDF::OpenAnnotation.hasTarget)).to eq ["http://purl.stanford.edu/kq131cs7229"]

      expect(result_array[2].id_as_url).to match a_string_ending_with"5686cffa-14c1-4aa4-8cef-bf62e9f4ab82"
      expect(result_array[2].body_chars).to eq ["testing redirect 2"]
      expect(result_array[2].predicate_urls(RDF::OpenAnnotation.hasTarget)).to eq ["http://purl.stanford.edu/oo111oo2222"]
    end
    it "gets jsonld context from local cache" do
      skip "code and test to be implemented"
      fail "code and test to be implemented"
    end
  end
  
end