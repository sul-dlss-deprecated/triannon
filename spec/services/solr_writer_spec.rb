require 'spec_helper'

describe Triannon::SolrWriter, :vcr do
  context '#initialize' do
    it "sets up Rsolr client with solr_url from Triannon.yml" do
      expect(RSolr).to receive(:connect).with(:url => Triannon.config[:solr_url])
      Triannon::SolrWriter.new
    end
  end

  let(:solr_writer) { Triannon::SolrWriter.new }

  context '#write' do
    let(:uuid) {"814b0225-bd48-4de9-a724-a72a9fa86c18"}
    let(:base_url) {"https://triannon-dev.stanford.edu/annotations/"}
    let(:tg) {OA::Graph.new RDF::Graph.new.from_ttl "
     <#{base_url}#{uuid}> a <http://www.w3.org/ns/oa#Annotation>;
       <http://www.w3.org/ns/oa#annotatedAt> \"2015-01-07T18:01:21Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>;
       <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666>;
       <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#bookmarking> ." }
    it "calls .solr_hash for tgraph param" do
      expect(Triannon::SolrWriter).to receive(:solr_hash).with(tg)
      solr_writer.write(tg)
    end
    it "does NOT call solr_hash if tgraph param is nil" do
      expect(Triannon::SolrWriter).not_to receive(:solr_hash)
      solr_writer.write(nil)
    end
    it "does NOT call solr_hash if tgraph.id_as_url is nil" do
      expect(Triannon::SolrWriter).not_to receive(:solr_hash)
      my_tg = OA::Graph.new RDF::Graph.new.from_ttl "
         <> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#annotatedAt> \"2015-01-07T18:01:21Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>;
           <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666>;
           <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#bookmarking> ."
      solr_writer.write(my_tg)
    end
    it "calls #add" do
      expect(solr_writer).to receive(:add).with(Triannon::SolrWriter.solr_hash(tg))
      solr_writer.write(tg)
    end
    it "does NOT call #add if doc hash is nil" do
      expect(solr_writer).not_to receive(:add)
      allow(Triannon::SolrWriter).to receive(:solr_hash).with(tg).and_return(nil)
      solr_writer.write(tg)
    end
    it "does NOT call #add if doc hash is empty" do
      expect(solr_writer).not_to receive(:add)
      allow(Triannon::SolrWriter).to receive(:solr_hash).with(tg).and_return({})
      solr_writer.write(tg)
    end
  end

  context '#add' do
    let (:doc_hash) { {:id => '666'} }
    it "calls RSolr::Client.add with hash and commitWithin=500" do
      expect_any_instance_of(RSolr::Client).to receive(:add).with(doc_hash, :add_attributes => {:commitWithin=> 500})
      solr_writer.add(doc_hash)
    end
    it "uses with_retries" do
      expect(solr_writer).to receive(:with_retries)
      solr_writer.add(doc_hash)
    end
    context 'SearchError' do
      it "raised when StandardError rescued" do
        my_rsolr_client = double()
        err_msg_from_rsolr = "some flavor of Runtime exception"
        allow(my_rsolr_client).to receive(:add).and_raise(RuntimeError.new(err_msg_from_rsolr))

        solr_writer.rsolr_client = my_rsolr_client

        expect { solr_writer.add(doc_hash) }.to raise_error { |error|
          expect(error).to be_a Triannon::SearchError
          expect(error.message).to eq "error adding doc #{doc_hash[:id]} to Solr #{doc_hash}; #{err_msg_from_rsolr}"
        }
      end
      it "raised when RSolr error rescued" do
        my_rsolr_client = double()
        solr_resp_body = "response body from Solr"
        solr_resp_status = 412
        allow(my_rsolr_client).to receive(:add).and_raise(RSolr::Error::Http.new({:uri => "hahaha"}, {status: solr_resp_status, body: solr_resp_body}))

        solr_writer.rsolr_client = my_rsolr_client

        expect { solr_writer.add(doc_hash) }.to raise_error { |error|
          expect(error).to be_a Triannon::SearchError
          expect(error.message).to match "error adding doc #{doc_hash[:id]} to Solr #{doc_hash}; RSolr::Error::Http"
          expect(error.search_resp_status).to eq solr_resp_status
          expect(error.search_resp_body).to eq solr_resp_body
        }
      end
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
    context 'SearchError' do
      it "raised when StandardError rescued" do
        my_rsolr_client = double()
        err_msg_from_rsolr = "some flavor of Runtime exception"
        allow(my_rsolr_client).to receive(:delete_by_id).and_raise(RuntimeError.new(err_msg_from_rsolr))

        solr_writer.rsolr_client = my_rsolr_client

        expect { solr_writer.delete("foo") }.to raise_error { |error|
          expect(error).to be_a Triannon::SearchError
          expect(error.message).to eq "error deleting doc foo from Solr: #{err_msg_from_rsolr}"
        }
      end
      it "raised when RSolr error rescued" do
        my_rsolr_client = double()
        solr_resp_body = "response body from Solr"
        solr_resp_status = 412
        allow(my_rsolr_client).to receive(:delete_by_id).and_raise(RSolr::Error::Http.new({:uri => "hahaha"}, {status: solr_resp_status, body: solr_resp_body}))

        solr_writer.rsolr_client = my_rsolr_client

        expect { solr_writer.delete("foo") }.to raise_error { |error|
          expect(error).to be_a Triannon::SearchError
          expect(error.message).to match "error deleting doc foo from Solr: RSolr::Error::Http"
          expect(error.search_resp_status).to eq solr_resp_status
          expect(error.search_resp_body).to eq solr_resp_body
        }
      end
    end
  end

  context '.solr_hash' do
    let(:uuid) {"814b0225-bd48-4de9-a724-a72a9fa86c18"}
    let(:base_url) {"https://triannon-dev.stanford.edu/annotations/"}
    let(:tg) {OA::Graph.new RDF::Graph.new.from_ttl "
     <#{base_url}#{uuid}> a <http://www.w3.org/ns/oa#Annotation>;
       <http://www.w3.org/ns/oa#annotatedAt> \"2015-01-07T18:01:21Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>;
       <http://www.w3.org/ns/oa#hasBody> [
         a <http://purl.org/dc/dcmitype/Text>,
           <http://www.w3.org/2011/content#ContentAsText>;
         <http://purl.org/dc/terms/format> \"text/plain\";
         <http://www.w3.org/2011/content#chars> \"blah blah\"
       ];
       <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666>;
       <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#tagging> ." }
    let(:sw_solr_hash) {
      config = { :triannon_base_url => base_url }
      allow(Triannon).to receive(:config).and_return(config)
      Triannon::SolrWriter.solr_hash(tg)
    }

    context 'id' do
      it "is a String" do
        expect(sw_solr_hash[:id]).to be_a String
      end
      it "only the uuid, not the full url" do
        expect(sw_solr_hash[:id]).to eq uuid
      end
      it "slash not part of base_url" do
        config = { :triannon_base_url =>  "https://triannon-dev.stanford.edu/annotations" }
        allow(Triannon).to receive(:config).and_return(config)
        my_tg = OA::Graph.new RDF::Graph.new.from_ttl "
         <#{base_url}/#{uuid}> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666>;
           <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#tagging> ."
        expect(Triannon::SolrWriter.solr_hash(my_tg)[:id]).to eq uuid
      end
      it "slash part of base_url" do
        # see 'only the uuid, not the full url'
      end
      it "calls id_as_url in OA::Graph instance" do
        expect(tg).to receive(:id_as_url).and_call_original
        Triannon::SolrWriter.solr_hash tg
      end
    end

    context 'motivation' do
      it "is an Array" do
        expect(sw_solr_hash[:motivation]).to be_an Array
      end
      it "calls motivated_by" do
        expect(tg).to receive(:motivated_by).and_call_original
        Triannon::SolrWriter.solr_hash tg
      end
      it "uses short Strings, not the full urls" do
        expect(sw_solr_hash[:motivation]).to eq ["tagging"]
      end
    end

    context 'annotated_at' do
      it "is a String" do
        expect(sw_solr_hash[:annotated_at]).to be_a String
      end
      it "format accepted by Solr for date field" do
        # date field format: 1995-12-31T23:59:59Z; or w fractional seconds: 1995-12-31T23:59:59.999Z
        expect(sw_solr_hash[:annotated_at]).to eq "2015-01-07T18:01:21Z"
      end
      it "calls annotated_at" do
        expect(tg).to receive(:annotated_at)
        Triannon::SolrWriter.solr_hash tg
      end
      it "calls Time.parse" do
        expect(Time).to receive(:parse)
        Triannon::SolrWriter.solr_hash tg
      end
      it "nil if date won't parse cleanly" do
        my_tg = OA::Graph.new RDF::Graph.new.from_ttl "
         <https://sul-fedora-dev-a.stanford.edu/fedora/rest/anno/f3bc7da9-d531-4b0c-816a-8f2fc849b0b6> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#annotatedAt> \"not a date\" ."
        expect(Triannon::SolrWriter.solr_hash(my_tg)[:annotated_at]).to eq nil
      end
    end

    context 'target_url' do
      it "is an Array of urls as Strings" do
        expect(sw_solr_hash[:target_url]).to be_an Array
        expect(sw_solr_hash[:target_url].first).to be_a String
        expect(sw_solr_hash[:target_url].first).to match /^http/
      end
      it "calls predicate_urls with hasTarget" do
        allow(tg).to receive(:predicate_urls).with(RDF::Vocab::OA.hasBody).and_call_original
        expect(tg).to receive(:predicate_urls).with(RDF::Vocab::OA.hasTarget).and_call_original
        Triannon::SolrWriter.solr_hash tg
      end
      it "is empty array if no target is a url" do
        my_g = OA::Graph.new RDF::Graph.new.from_ttl Triannon.annotation_fixture("target-choice.ttl")
        expect(Triannon::SolrWriter.solr_hash(my_g)[:target_url]).to eq []
      end
    end
    context 'target_type' do
      # TODO: recognize more target types
      it "is an Array with 'external_URI' if a target is a url" do
        expect(sw_solr_hash[:target_type]).to be_an Array
        expect(sw_solr_hash[:target_type].first).to be_a String
        expect(sw_solr_hash[:target_type].first).to eq 'external_URI'
      end
      it "has external_URI once if multiple targets" do
        g3 = OA::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-targets.json")
        expect(Triannon::SolrWriter.solr_hash(g3)[:target_type]).to eq ['external_URI']
      end
      it "is nil if no target is a url" do
        my_g = OA::Graph.new RDF::Graph.new.from_ttl Triannon.annotation_fixture("target-choice.ttl")
        expect(Triannon::SolrWriter.solr_hash(my_g)[:target_type]).to be nil
      end
    end

    context 'body_url' do
      it "is an Array of urls as Strings" do
        my_g = OA::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-url.json")
        my_body_urls = Triannon::SolrWriter.solr_hash(my_g)[:body_url]
        expect(my_body_urls).to be_an Array
        expect(my_body_urls.first).to be_a String
        expect(my_body_urls.first).to match /^http/
      end
      it "calls predicate_urls with hasBody" do
        allow(tg).to receive(:predicate_urls).with(RDF::Vocab::OA.hasTarget).and_call_original
        expect(tg).to receive(:predicate_urls).with(RDF::Vocab::OA.hasBody).and_call_original
        Triannon::SolrWriter.solr_hash tg
      end
      it "is empty array if no bodies are urls" do
        expect(sw_solr_hash[:body_url]).to eq []
      end
    end
    context 'body_chars_exact' do
      it "is an Array of Strings" do
        my_body_chars = sw_solr_hash[:body_chars_exact]
        expect(my_body_chars).to be_an Array
        expect(my_body_chars.first).to be_a String
        expect(my_body_chars.first).to eq 'blah blah'
      end
      it "calls body_chars" do
        expect(tg).to receive(:body_chars).and_call_original
        Triannon::SolrWriter.solr_hash tg
      end
      it "strips the Strings" do
        my_ttl = "
         <#{base_url}#{uuid}> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#hasBody> [
             a <http://purl.org/dc/dcmitype/Text>,
               <http://www.w3.org/2011/content#ContentAsText>;
             <http://purl.org/dc/terms/format> \"text/plain\";
             <http://www.w3.org/2011/content#chars> \"  spaces  \"
           ];
           <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666>;
           <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#tagging> ."
        my_tg = OA::Graph.new RDF::Graph.new.from_ttl my_ttl
        expect(Triannon::SolrWriter.solr_hash(my_tg)[:body_chars_exact]).to eq ['spaces']
      end
      it "empty Array if no bodies are contentAsText" do
        my_g = OA::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-url.json")
        expect(Triannon::SolrWriter.solr_hash(my_g)[:body_chars_exact]).to eq []
      end
    end
    context 'body_type' do
      it "is an Array with 'external_URI' if a body is a url" do
        my_g = OA::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-url.json")
        my_body_types = Triannon::SolrWriter.solr_hash(my_g)[:body_type]
        expect(my_body_types).to be_an Array
        expect(my_body_types.first).to be_a String
        expect(my_body_types.first).to eq 'external_URI'
      end
      it "includes content_as_text if a body is as such" do
        expect(sw_solr_hash[:body_type]).to eq ['content_as_text']
      end
      it "has all types represented by multiple bodies" do
        my_g = OA::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-bodies.json")
        my_body_types = Triannon::SolrWriter.solr_hash(my_g)[:body_type]
        expect(my_body_types.size).to eq 2
        expect(my_body_types).to include 'external_URI'
        expect(my_body_types).to include 'content_as_text'
      end
      it "is 'no_body' if there is no body" do
        g2 = OA::Graph.new RDF::Graph.new.from_jsonld(
          '{
              "@context": "http://www.w3.org/ns/oa-context-20130208.json",
              "@id": "http://my.identifiers.com/oa_bookmark",
              "@type": "oa:Annotation",
              "motivatedBy": "oa:bookmarking",
              "hasTarget": "http://purl.stanford.edu/kq131cs7229"
            }' )
        expect(Triannon::SolrWriter.solr_hash(g2)[:body_type]).to eq ['no_body']
      end
    end

    context 'anno_jsonld' do
      it "is a String" do
        expect(sw_solr_hash[:anno_jsonld]).to be_a String
      end
      it "calls jsonld_oa" do
        expect(tg).to receive(:jsonld_oa)
        Triannon::SolrWriter.solr_hash tg
      end
      it "is entire anno as jsonld" do
        my_tg = OA::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-bodies.json")
        expect(Triannon::SolrWriter.solr_hash(my_tg)[:anno_jsonld]).to eq my_tg.jsonld_oa
      end
      it "has OA context" do
        my_tg = OA::Graph.new RDF::Graph.new.from_jsonld '
          {
              "@context":"http://iiif.io/api/presentation/2/context.json",
              "@id": "http://my.cool.anno/id",
              "@type":"oa:Annotation",
              "motivation":"oa:commenting",
              "resource": {
                "@type":"cnt:ContentAsText",
                "chars":"I love this!",
                "format":"text/plain",
                "language":"en"
              },
              "on":"http://purl.stanford.edu/kq131cs7229"
          }'
        expect(Triannon::SolrWriter.solr_hash(my_tg)[:anno_jsonld]).to match OA::Graph::OA_DATED_CONTEXT_URL
        expect(Triannon::SolrWriter.solr_hash(my_tg)[:anno_jsonld]).not_to match OA::Graph::IIIF_CONTEXT_URL
        my_tg = OA::Graph.new RDF::Graph.new.from_ttl Triannon.annotation_fixture("body-chars.ttl")
        expect(Triannon::SolrWriter.solr_hash(my_tg)[:anno_jsonld]).to match OA::Graph::OA_DATED_CONTEXT_URL
      end
      it "has non-empty id value for outer node" do
        expect(sw_solr_hash[:anno_jsonld]).not_to match "@id\":\"\""
        expect(sw_solr_hash[:anno_jsonld]).to match "@id\":\".+\""
      end
    end
  end # solr_hash

end
