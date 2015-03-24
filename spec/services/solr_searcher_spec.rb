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
  
  
  context '.solr_params' do
    it "no q param if nothing generates a q term" do
      expect(Triannon::SolrSearcher.solr_params({})).not_to include :q
      expect(Triannon::SolrSearcher.solr_params('motivatedBy' => 'commenting')).not_to include :q
    end
    it "no fq param if nothing generates fq" do
      expect(Triannon::SolrSearcher.solr_params({})).not_to include :fq
      expect(Triannon::SolrSearcher.solr_params('targetUri' => "some.url.org")).not_to include :fq
    end
    it "single q param for multiple terms" do
      solr_params = Triannon::SolrSearcher.solr_params('targetUri' => "some.url.org", 'bodyExact' => "foo")
      expect(solr_params[:q]).to be_truthy
      expect(q_includes_term('target_url:some.url.org', solr_params)).to be true
      expect(q_includes_term('body_chars_exact:"foo"', solr_params)).to be true
    end
    it "fq param value is an Array" do
      solr_params = Triannon::SolrSearcher.solr_params('motivatedBy' => 'commenting')
      expect(solr_params[:fq]).to be_an Array
    end
=begin TODO: implement these tests when we are further along
    it "multiple fq params" do
      fail "test to be implemented"
    end
=end

    context 'targetUri' do
      it "creates term in q param" do
        expect(Triannon::SolrSearcher.solr_params('targetUri' => "some.url.org")).to include :q
      end
      it "causes Solr defType=lucene" do
        expect(Triannon::SolrSearcher.solr_params('targetUri' => "some.url.org")).to include :defType => 'lucene'
      end
      it "maps to Solr target_url" do
        expect(q_includes_term('target_url:some.url.org', Triannon::SolrSearcher.solr_params('targetUri' => "some.url.org"))).to be true
      end
      it "calls q_terms_for_url" do
        expect(Triannon::SolrSearcher).to receive(:q_terms_for_url).with("target_url", "some.url.org")
        Triannon::SolrSearcher.solr_params('targetUri' => "some.url.org")
      end
      it "Solr escapes value" do
        expect(RSolr).to receive(:solr_escape).at_least(:once).with("some.url.org/foo").and_call_original
        expect(q_includes_term('target_url:some.url.org\/foo', Triannon::SolrSearcher.solr_params('targetUri' => "some.url.org/foo"))).to be true
      end
      it "controller param key not case sensitive" do
        ['targetUri', 'targeturi', 'TargetUri'].each { |str|
          expect(q_includes_term('target_url:some.url.org', Triannon::SolrSearcher.solr_params(str => "some.url.org"))).to be true
        }
      end
    end # targetUri

=begin TODO: implement more searching params
    context 'targetType' do
      it "creates fq param" do
        fail "test to be implemented"
      end
      it "maps to Solr target_type" do
        skip "code and tests to be implemented"
        fail "test to be implemented"
      end
      it "works for full url and frag only" do
        fail "test to be implemented"
      end
      it "Solr escapes value" do
        fail "test to be implemented"
      end
    end
=end

    context 'bodyUri' do
      it "creates term in q param" do
        expect(Triannon::SolrSearcher.solr_params('bodyUri' => "some.url.org")).to include :q
      end
      it "causes Solr defType=lucene" do
        expect(Triannon::SolrSearcher.solr_params('bodyUri' => "some.url.org")).to include :defType => 'lucene'
      end
      it "maps to Solr body_url" do
        expect(q_includes_term('body_url:some.url.org', Triannon::SolrSearcher.solr_params('bodyUri' => "some.url.org"))).to be true
      end
      it "calls q_terms_for_url" do
        expect(Triannon::SolrSearcher).to receive(:q_terms_for_url).with("body_url", "some.url.org")
        Triannon::SolrSearcher.solr_params('bodyUri' => "some.url.org")
      end
      it "Solr escapes body_url value" do
        expect(RSolr).to receive(:solr_escape).at_least(:once).and_call_original
        expect(q_includes_term('body_url:http\:\/\/some.url.org\/foo', Triannon::SolrSearcher.solr_params('bodyUri' => "http://some.url.org/foo"))).to be true
      end
      it "param key not case sensitive" do
        ['bodyUri', 'bodyuri', 'BodyUri'].each { |str|
          expect(q_includes_term('body_url:some.url.org', Triannon::SolrSearcher.solr_params(str => "some.url.org"))).to be true
        }
      end
    end # bodyUri

    context 'bodyExact' do
      it "causes Solr defType=lucene" do
        expect(Triannon::SolrSearcher.solr_params('bodyExact' => "I'm a tag!")).to include :defType => 'lucene'
      end
      it "maps to q term body_chars_exact" do
        expect(Triannon::SolrSearcher.solr_params('bodyExact' => "tag")).to include :q => "body_chars_exact:\"tag\""
      end
      it "adds quotes to value" do
        expect(Triannon::SolrSearcher.solr_params('bodyExact' => "I'm a tag")).to include :q => "body_chars_exact:\"I'm a tag\""
      end
      it "does NOT Solr escape value (because it's in quotes)" do
        expect(RSolr).not_to receive(:solr_escape)
        expect(Triannon::SolrSearcher.solr_params('bodyExact' => "I'm a tag! & I [hate|love]")).to include :q => "body_chars_exact:\"I'm a tag! & I [hate|love]\""
      end
      it "param key not case sensitive" do
        ['bodyExact', 'bodyexact', 'BodyExact'].each { |str|
          expect(Triannon::SolrSearcher.solr_params({str => "tagit"})).to include :q => 'body_chars_exact:"tagit"'
        }
      end
    end # bodyExact

    context 'bodyKeyword' do
      it "causes Solr defType=lucene" do
        expect(Triannon::SolrSearcher.solr_params('bodyKeyword' => "word")).to include :defType => 'lucene'
      end
      it "kqf param with Solr fields and boosts for deferencing multifield qf" do
        solr_params = Triannon::SolrSearcher.solr_params('bodyKeyword' => "word")
        expect(solr_params).to include :kqf => 'body_chars_exact^3 body_chars_unstem^2 body_chars_stem'
        expect(solr_params).to include :q => a_string_matching(/ qf=\$kqf /)
      end
      it "kpf param with Solr fields and boosts for deferencing multifield pf" do
        solr_params = Triannon::SolrSearcher.solr_params('bodyKeyword' => "word")
        expect(solr_params).to include :kpf => 'body_chars_exact^15 body_chars_unstem^10 body_chars_stem^5'
        expect(solr_params).to include :q => a_string_matching(/ pf=\$kpf /)
      end
      it "kpf3 param with Solr fields and boosts for deferencing multifield pf3" do
        solr_params = Triannon::SolrSearcher.solr_params('bodyKeyword' => "word")
        expect(solr_params).to include :kpf3 => 'body_chars_exact^9 body_chars_unstem^6 body_chars_stem^3'
        expect(solr_params).to include :q => a_string_matching(/ pf3=\$kpf3 /)
      end
      it "kpf2 param with Solr fields and boosts for deferencing multifield pf2" do
        solr_params = Triannon::SolrSearcher.solr_params('bodyKeyword' => "word")
        expect(solr_params).to include :kpf2 => 'body_chars_exact^6 body_chars_unstem^4 body_chars_stem^2'
        expect(solr_params).to include :q => a_string_matching(/ pf2=\$kpf2/)
      end
      it "maps to q _query_ term using kqf, kpf, kpf3, kpf2" do
        expect(Triannon::SolrSearcher.solr_params('bodyKeyword' => "word but")).to include :q => '_query_:"{!dismax qf=$kqf pf=$kpf pf3=$kpf3 pf2=$kpf2}word but"'
      end
      it "Solr escapes value" do
        raw_value = 'solr escape " double quote'
        expect(RSolr).to receive(:solr_escape).with(raw_value).and_call_original
        solr_params = Triannon::SolrSearcher.solr_params('bodyKeyword' => raw_value)
        expect(solr_params).not_to include :q => a_string_matching(raw_value)
        expect(solr_params).to include :q => a_string_matching(/solr escape \\" double quote/)
      end
      it "param key not case sensitive" do
        ['bodyKeyword', 'bodykeyword', 'BodyKeyword'].each { |str|
          expect(Triannon::SolrSearcher.solr_params(str => "word")).to include :q => a_string_matching(/word/)
        }
      end
    end

=begin TODO: implement more searching params
    context 'bodyType' do
      it "creates fq param" do
        fail "test to be implemented"
      end
      it "maps to Solr body_type" do
        skip "code and tests to be implemented"
        fail "test to be implemented"
      end
      it "Solr escapes value" do
        fail "test to be implemented"
      end
    end
=end

    context 'motivatedBy' do
      it "maps to Solr fq motivation" do
        expect(Triannon::SolrSearcher.solr_params("motivatedBy" => 'commenting')).to include :fq => ["motivation:commenting"]
      end
      it "param value as full URI maps to fragment portion as value" do
        expect(Triannon::SolrSearcher.solr_params("motivatedBy" => 'http://www.w3.org/ns/oa#commenting')).to include :fq => ["motivation:commenting"]
      end
      it "param value can be fragment only" do
        expect(Triannon::SolrSearcher.solr_params("motivatedBy" => 'commenting')).to include :fq => ["motivation:commenting"]
      end
      context 'sc:painting' do
        it "http://iiif.io/api/presentation/2#painting" do
          expect(Triannon::SolrSearcher.solr_params('motivatedBy' => 'http://iiif.io/api/presentation/2#painting')).to include :fq => ["motivation:painting"]
        end
        it "http://www.shared-canvas.org/ns/painting" do
          expect(Triannon::SolrSearcher.solr_params('motivatedBy' => 'http://www.shared-canvas.org/ns/painting')).to include :fq => ["motivation:painting"]
        end
        it "sc:painting" do
          expect(Triannon::SolrSearcher.solr_params('motivatedBy' => 'sc:painting')).to include :fq => ["motivation:painting"]
        end
        it "painting" do
          expect(Triannon::SolrSearcher.solr_params('motivatedBy' => 'painting')).to include :fq => ["motivation:painting"]
        end
      end
      it "Solr escapes value" do
        raw_value = "a!b[c|d]"
        expect(RSolr).to receive(:solr_escape).with(raw_value).and_call_original
        solr_params = Triannon::SolrSearcher.solr_params('motivatedBy' => raw_value)
        expect(solr_params).not_to include :fq => [ (a_string_ending_with(raw_value))]
        expect(solr_params).to include :fq => [ a_string_ending_with("a\\!b\\[c\\|d\\]") ]
      end
      it "param key not case sensitive" do
        ['motivatedBy', 'motivatedby', 'MotivatedBy'].each { |str|
          expect(Triannon::SolrSearcher.solr_params(str => "tagging")).to include :fq => ['motivation:tagging']
        }
      end
    end

=begin TODO: implement more searching params
    context 'annotatedAt' do
      it "creates fq param" do
        fail "test to be implemented"
      end
      it "maps to Solr annotated_at" do
        fail "test to be implemented"
      end
      it "value is in 1995-12-31T23:59:59Z format " do
        fail "test to be implemented"
      end
      it "value is wildcarded if less specific" do
        fail "test to be implemented"
      end
      it "value is mapped to facet.date.start" do
        fail "test to be implemented"
      end
      it "Solr escapes value" do
        fail "test to be implemented"
      end
    end

    context 'annotatedBy' do
      it "creates terms in q param" do
        fail "test to be implemented"
      end
      it "maps to Solr annotate_by_unstem" do
        skip "code and tests to be implemented"
        fail "test to be implemented"
      end
      it "maps to Solr annotate_by_stem" do
        skip "code and tests to be implemented"
        fail "test to be implemented"
      end
      it "Solr escapes value" do
        fail "test to be implemented"
      end
    end
=end
  end # solr_params
  
  
  context '.q_terms_for_url' do
    let (:fldname) { 'url_solr_field' }
    let (:url) { 'http://myplace.org' }
    it "exact match term" do
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, url)).to include "#{fldname}:#{RSolr.solr_escape(url)}"
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}#foo")).to include "#{fldname}:#{RSolr.solr_escape(url + '#foo')}"
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}/foo")).to include "#{fldname}:#{RSolr.solr_escape(url + '/foo')}"
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}/foo#bar")).to include "#{fldname}:#{RSolr.solr_escape(url + '/foo#bar')}"
    end
    it "frag wildcard term if no frag in url" do
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, url)).to include "#{fldname}:#{RSolr.solr_escape(url)}#*"
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}/foo")).to include "#{fldname}:#{RSolr.solr_escape(url + '/foo')}#*"
    end
    it "NO frag wildcard term if frag in url" do
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}#foo")).not_to include "#{fldname}:#{RSolr.solr_escape(url)}#*"
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}#foo")).not_to include "#{fldname}:#{RSolr.solr_escape(url + '#foo')}#*"
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}/foo#bar")).not_to include "#{fldname}:#{RSolr.solr_escape(url + '/foo')}#*"
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}/foo#bar")).not_to include "#{fldname}:#{RSolr.solr_escape(url + '/foo#bar')}#*"
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}/foo#bar")).not_to include "#{fldname}:#{RSolr.solr_escape(url)}#*"
    end
    it "NO url without frag if frag in url" do
      expect(Triannon::SolrSearcher.q_terms_for_url(fldname, "#{url}#foo")).not_to include "#{fldname}:#{RSolr.solr_escape(url)}#*"
    end
    it "calls RSolr.escape on value" do
      expect(RSolr).to receive(:solr_escape).with(url).exactly(2).times
      Triannon::SolrSearcher.q_terms_for_url(fldname, url)
    end
  end #q_terms_for_url
  
end

# handy for testing when multiple q terms are created
def q_includes_term term, solr_params
  qterms = solr_params[:q].split
  if qterms.include? term
    true
  else
    false
  end
end