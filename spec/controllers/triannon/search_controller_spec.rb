require 'spec_helper'

describe Triannon::SearchController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  describe "GET find" do
    it "returns http success" do
      get :find
      expect(response).to have_http_status(:success)
    end
=begin TODO: implement find action in controller
    it "translates the params to Solr params" do
      fail "test to be implemented"
    end
    it "sends a search to Solr" do
      fail "test to be implemented"
    end
    it "reads each anno in the Solr response" do
      fail "test to be implemented"
    end
    it "returns a IIIF Annotation List" do
      fail "test to be implemented"
    end
    it "returns jsonld annos in IIIF context" do
      fail "test to be implemented"
    end
    context 'response formats' do
      context 'jsonld context' do
 
      end
    end
=end
  end # GET find


  context '#solr_params' do
    it "no q param if nothing generates a q term" do
      get :find
      expect(controller.send(:solr_params)).not_to include :q
      get :find, motivation: 'commenting'
      expect(controller.send(:solr_params)).not_to include :q
    end
    it "no fq param if nothing generates fq" do
      get :find
      expect(controller.send(:solr_params)).not_to include :fq
      get :find, targetUri: "some.url.org"
      expect(controller.send(:solr_params)).not_to include :fq
    end
    it "single q param for multiple terms" do
      get :find, targetUri: "some.url.org", bodyExact: "foo"
      solr_params = controller.send(:solr_params)
      expect(solr_params[:q]).to be_truthy
      expect(q_includes_term('target_url:some.url.org', solr_params)).to be true
      expect(q_includes_term('body_chars_exact:"foo"', solr_params)).to be true
    end
    it "fq param value is an Array" do
      get :find, motivatedBy: 'commenting'
      solr_params = controller.send(:solr_params)
      expect(solr_params[:fq]).to be_an Array
    end
=begin TODO: implement these tests when we are further along
    it "multiple fq params" do
      fail "test to be implemented"
    end
=end

    context 'targetUri' do
      it "creates term in q param" do
        get :find, targetUri: "some.url.org"
        expect(controller.send(:solr_params)).to include :q
      end
      it "causes Solr defType=lucene" do
        get :find, targetUri: "some.url.org"
        expect(controller.send(:solr_params)).to include :defType => 'lucene'
      end
      it "maps to Solr target_url" do
        get :find, targetUri: "some.url.org"
        expect(q_includes_term('target_url:some.url.org', controller.send(:solr_params))).to be true
      end
      it "calls q_terms_for_url" do
        expect(controller).to receive(:q_terms_for_url).with("target_url", "some.url.org")
        get :find, targetUri: "some.url.org"
        # solr_params is called by action method
      end
      it "Solr escapes value" do
        get :find, targetUri: "some.url.org/foo"
        expect(RSolr).to receive(:solr_escape).at_least(:once).with("some.url.org/foo").and_call_original
        expect(q_includes_term('target_url:some.url.org\/foo', controller.send(:solr_params))).to be true
      end
      it "param key not case sensitive" do
        [:targetUri, :targeturi, :TargetUri].each { |sym|
          get :find, {sym => "some.url.org"}
          expect(q_includes_term('target_url:some.url.org', controller.send(:solr_params))).to be true
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
        get :find, bodyUri: "some.url.org"
        expect(controller.send(:solr_params)).to include :q
      end
      it "causes Solr defType=lucene" do
        get :find, bodyUri: "some.url.org"
        expect(controller.send(:solr_params)).to include :defType => 'lucene'
      end
      it "maps to Solr body_url" do
        get :find, bodyUri: "some.url.org"
        expect(q_includes_term('body_url:some.url.org', controller.send(:solr_params))).to be true
      end
      it "calls q_terms_for_url" do
        expect(controller).to receive(:q_terms_for_url).with("body_url", "some.url.org")
        get :find, bodyUri: "some.url.org"
        # solr_params is called by action method
      end
      it "Solr escapes body_url value" do
        get :find, bodyUri: "http://some.url.org/foo"
        expect(RSolr).to receive(:solr_escape).at_least(:once).and_call_original
        expect(q_includes_term('body_url:http\:\/\/some.url.org\/foo', controller.send(:solr_params))).to be true
      end
      it "param key not case sensitive" do
        [:bodyUri, :bodyuri, :BodyUri].each { |sym|  
          get :find, {sym => "some.url.org"}
          expect(q_includes_term('body_url:some.url.org', controller.send(:solr_params))).to be true
        }
      end
    end # bodyUri

    context 'bodyExact' do
      it "causes Solr defType=lucene" do
        get :find, bodyExact: "I'm a tag!"
        expect(controller.send(:solr_params)).to include :defType => 'lucene'
      end
      it "maps to q term body_chars_exact" do
        get :find, bodyExact: "tag"
        expect(controller.send(:solr_params)).to include :q => "body_chars_exact:\"tag\""
      end
      it "adds quotes to value" do
        get :find, bodyExact: "I'm a tag"
        expect(controller.send(:solr_params)).to include :q => "body_chars_exact:\"I'm a tag\""
      end
      it "does NOT Solr escape value (because it's in quotes)" do
        get :find, bodyExact: "I'm a tag! & I [hate|love]"
        expect(RSolr).not_to receive(:solr_escape)
        expect(controller.send(:solr_params)).to include :q => "body_chars_exact:\"I'm a tag! & I [hate|love]\""
      end
      it "param key not case sensitive" do
        [:bodyExact, :bodyexact, :BodyExact].each { |sym|
          get :find, {sym => "tagit"}
          expect(controller.send(:solr_params)).to include :q => 'body_chars_exact:"tagit"'
        }
      end
    end # bodyExact

    context 'bodyKeyword' do
      it "causes Solr defType=lucene" do
        get :find, bodyKeyword: "word"
        expect(controller.send(:solr_params)).to include :defType => 'lucene'
      end
      it "kqf param with Solr fields and boosts for deferencing multifield qf" do
        get :find, bodyKeyword: "word"
        solr_params = controller.send(:solr_params)
        expect(solr_params).to include :kqf => 'body_chars_exact^3 body_chars_unstem^2 body_chars_stem'
        expect(solr_params).to include :q => a_string_matching(/ qf=\$kqf /)
      end
      it "kpf param with Solr fields and boosts for deferencing multifield pf" do
        get :find, bodyKeyword: "word"
        solr_params = controller.send(:solr_params)
        expect(solr_params).to include :kpf => 'body_chars_exact^15 body_chars_unstem^10 body_chars_stem^5'
        expect(solr_params).to include :q => a_string_matching(/ pf=\$kpf /)
      end
      it "kpf3 param with Solr fields and boosts for deferencing multifield pf3" do
        get :find, bodyKeyword: "word"
        solr_params = controller.send(:solr_params)
        expect(solr_params).to include :kpf3 => 'body_chars_exact^9 body_chars_unstem^6 body_chars_stem^3'
        expect(solr_params).to include :q => a_string_matching(/ pf3=\$kpf3 /)
      end
      it "kpf2 param with Solr fields and boosts for deferencing multifield pf2" do
        get :find, bodyKeyword: "word"
        solr_params = controller.send(:solr_params)
        expect(solr_params).to include :kpf2 => 'body_chars_exact^6 body_chars_unstem^4 body_chars_stem^2'
        expect(solr_params).to include :q => a_string_matching(/ pf2=\$kpf2/)
      end
      it "maps to q _query_ term using kqf, kpf, kpf3, kpf2" do
        get :find, bodyKeyword: "word but"
        expect(controller.send(:solr_params)).to include :q => '_query_:"{!dismax qf=$kqf pf=$kpf pf3=$kpf3 pf2=$kpf2}word but"'
      end
      it "Solr escapes value" do
        raw_value = 'solr escape " double quote'
        get :find, bodyKeyword: raw_value
        expect(RSolr).to receive(:solr_escape).with(raw_value).and_call_original
        solr_params = controller.send(:solr_params)
        expect(solr_params).not_to include :q => a_string_matching(raw_value)
        expect(solr_params).to include :q => a_string_matching(/solr escape \\" double quote/)
      end
      it "param key not case sensitive" do
        [:bodyKeyword, :bodykeyword, :BodyKeyword].each { |sym|
          get :find, {sym => "word"}
          expect(controller.send(:solr_params)).to include :q => a_string_matching(/word/)
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
        get :find, motivatedBy: 'commenting'
        expect(controller.send(:solr_params)).to include :fq => ["motivation:commenting"]
      end
      it "param value as full URI maps to fragment portion as value" do
        get :find, motivatedBy: 'http://www.w3.org/ns/oa#commenting'
        expect(controller.send(:solr_params)).to include :fq => ["motivation:commenting"]
      end
      it "param value can be fragment only" do
        get :find, motivatedBy: 'commenting'
        expect(controller.send(:solr_params)).to include :fq => ["motivation:commenting"]
      end
      context 'sc:painting' do
        it "http://iiif.io/api/presentation/2#painting" do
          get :find, motivatedBy: 'http://iiif.io/api/presentation/2#painting'
          expect(controller.send(:solr_params)).to include :fq => ["motivation:painting"]
        end
        it "http://www.shared-canvas.org/ns/painting" do
          get :find, motivatedBy: 'http://www.shared-canvas.org/ns/painting'
          expect(controller.send(:solr_params)).to include :fq => ["motivation:painting"]
        end
        it "sc:painting" do
          get :find, motivatedBy: 'sc:painting'
          expect(controller.send(:solr_params)).to include :fq => ["motivation:painting"]
        end
        it "painting" do
          get :find, motivatedBy: 'painting'
          expect(controller.send(:solr_params)).to include :fq => ["motivation:painting"]
        end
      end
      it "Solr escapes value" do
        raw_value = "a!b[c|d]"
        get :find, motivatedBy: raw_value
        expect(RSolr).to receive(:solr_escape).with(raw_value).and_call_original
        solr_params = controller.send(:solr_params)
        expect(solr_params).not_to include :fq => [ (a_string_ending_with(raw_value))]
        expect(solr_params).to include :fq => [ a_string_ending_with("a\\!b\\[c\\|d\\]") ]
      end
      it "param key not case sensitive" do
        [:motivatedBy, :motivatedby, :MotivatedBy].each { |sym|
          get :find, {sym => "tagging"}
          expect(controller.send(:solr_params)).to include :fq => ['motivation:tagging']
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

  context '#q_terms_for_url' do
    let (:fname) { 'url_solr_field' }
    let (:url) {'http://myplace.org'}
    it "exact match term" do
      expect(controller.send(:q_terms_for_url, fname, url)).to include "#{fname}:#{RSolr.solr_escape(url)}"
      expect(controller.send(:q_terms_for_url, fname, "#{url}#foo")).to include "#{fname}:#{RSolr.solr_escape(url + '#foo')}"
      expect(controller.send(:q_terms_for_url, fname, "#{url}/foo")).to include "#{fname}:#{RSolr.solr_escape(url + '/foo')}"
      expect(controller.send(:q_terms_for_url, fname, "#{url}/foo#bar")).to include "#{fname}:#{RSolr.solr_escape(url + '/foo#bar')}"
    end
    it "frag wildcard term if no frag in url" do
      expect(controller.send(:q_terms_for_url, fname, url)).to include "#{fname}:#{RSolr.solr_escape(url)}#*"
      expect(controller.send(:q_terms_for_url, fname, "#{url}/foo")).to include "#{fname}:#{RSolr.solr_escape(url + '/foo')}#*"
    end
    it "NO frag wildcard term if frag in url" do
      expect(controller.send(:q_terms_for_url, fname, "#{url}#foo")).not_to include "#{fname}:#{RSolr.solr_escape(url)}#*"
      expect(controller.send(:q_terms_for_url, fname, "#{url}#foo")).not_to include "#{fname}:#{RSolr.solr_escape(url + '#foo')}#*"
      expect(controller.send(:q_terms_for_url, fname, "#{url}/foo#bar")).not_to include "#{fname}:#{RSolr.solr_escape(url + '/foo')}#*"
      expect(controller.send(:q_terms_for_url, fname, "#{url}/foo#bar")).not_to include "#{fname}:#{RSolr.solr_escape(url + '/foo#bar')}#*"
      expect(controller.send(:q_terms_for_url, fname, "#{url}/foo#bar")).not_to include "#{fname}:#{RSolr.solr_escape(url)}#*"
    end
    it "NO url without frag if frag in url" do
      expect(controller.send(:q_terms_for_url, fname, "#{url}#foo")).not_to include "#{fname}:#{RSolr.solr_escape(url)}#*"
    end
    it "calls RSolr.escape on value" do
      expect(RSolr).to receive(:solr_escape).with(url).exactly(2).times
      controller.send(:q_terms_for_url, fname, url)
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