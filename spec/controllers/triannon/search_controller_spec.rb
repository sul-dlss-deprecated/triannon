require 'spec_helper'

describe Triannon::SearchController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  describe "GET find" do
    let(:anno_graphs_array) { [
      OA::Graph.new(RDF::Graph.new.from_jsonld('
        { "@context":"http://www.w3.org/ns/oa-context-20130208.json",
          "@graph": [
            { "@id":"_:g70337046884060",
              "@type":["dctypes:Text","cnt:ContentAsText"],
              "chars":"I hate this!"
            },
            { "@id":"http://your.triannon-server.com/annotations/d3019689-d3ff-4290-8ee3-72fec2320332",
              "@type":"oa:Annotation",
              "hasBody":"_:g70337046884060",
              "hasTarget":"http://purl.stanford.edu/kq131cs7229",
              "motivatedBy":"oa:commenting"
            }
          ]
        }')),
      OA::Graph.new(RDF::Graph.new.from_jsonld('
        { "@context":"http://www.w3.org/ns/oa-context-20130208.json",
          "@graph": [
            { "@id":"_:g70337056969180",
              "@type":["dctypes:Text","cnt:ContentAsText"],
              "chars":"I love this!"
            },
            { "@id":"http://your.triannon-server.com/annotations/51558876-f6df-4da4-b268-02c8bff94391",
              "@type":"oa:Annotation",
              "hasBody":"_:g70337056969180",
              "hasTarget":"http://purl.stanford.edu/kq131cs7229",
              "motivatedBy":"oa:commenting"
            }
          ]
        }')),
      OA::Graph.new(RDF::Graph.new.from_jsonld('
        { "@context":"http://www.w3.org/ns/oa-context-20130208.json",
          "@graph": [
            { "@id":"_:g70252904268480",
              "@type":["dctypes:Text","cnt:ContentAsText"],
              "chars":"testing redirect 2"
            },
            { "@id":"http://your.triannon-server.com/annotations/5686cffa-14c1-4aa4-8cef-bf62e9f4ab82",
              "@type":"oa:Annotation",
              "hasBody":"_:g70252904268480",
              "hasTarget":"http://purl.stanford.edu/oo111oo2222",
              "motivatedBy":"oa:commenting"
            }
          ]
        }'))
      ] }

    it "returns http success" do
      get :find
      expect(response).to have_http_status(:success)
    end
    it "calls solr_searcher.find with params" do
      params = {'targetUri' => "some.url.org", 'bodyExact' => "foo"}
      ss = subject.send(:solr_searcher)
      expect(ss).to receive(:find).with(hash_including(params))
      get :find, params
    end
    it "calls IIIFAnnoList.anno_list" do
      ss = subject.send(:solr_searcher)
      allow(ss).to receive(:find).and_return(anno_graphs_array)
      expect(Triannon::IIIFAnnoList).to receive(:anno_list)
      get :find
    end
    it "adds triannon search url as @id to anno_list" do
      ss = subject.send(:solr_searcher)
      allow(ss).to receive(:find).and_return(anno_graphs_array)
      get :find, {'targetUri' => "some.url.org"}
      result = JSON.parse(response.body)
      expect(result).to be_a Hash
      expect(result).to include("@id" => "http://test.host/annotations/search?targetUri=some.url.org")
    end

    context "response format" do
      # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
      json_regex = /\A\{.+\}\Z/m

      def response_complete? response
        expect(response.body).to match "http://purl.stanford.edu/kq131cs7229"
        expect(response.body).to match "http://purl.stanford.edu/oo111oo2222"
        expect(response.body).to match "I hate this!"
        expect(response.body).to match "I love this!"
        expect(response.body).to match "testing redirect 2"
        expect(response.status).to eq 200
      end

      shared_examples_for 'accept header determines media type' do | mime_types, regex |
        mime_types.each { |mtype|
          it "#{mtype}" do
            request.accept = mtype
            ss = subject.send(:solr_searcher)
            allow(ss).to receive(:find).and_return(anno_graphs_array)
            get :find, {}
            expect(response.content_type).to eql mtype
            expect(response.body).to match regex
            response_complete? response
          end
        }
      end
      context "turtle" do
        # regex:  \Z is needed instead of $ due to \n in data)
        it_behaves_like 'accept header determines media type', ["text/turtle", "application/x-turtle"], /\.\Z/
      end
      context "rdfxml" do
        # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
        it_behaves_like 'accept header determines media type', ["application/rdf+xml", "text/rdf+xml", "text/rdf", "application/xml", "text/xml", "application/x-xml"], /\A<.+>\Z/m
      end
      context "json" do
        it_behaves_like 'accept header determines media type', ["application/ld+json", "application/json", "text/x-json", "application/jsonrequest"], json_regex
      end
      it "empty string gets json-ld" do
        request.accept = ""
        ss = subject.send(:solr_searcher)
        allow(ss).to receive(:find).and_return(anno_graphs_array)
        get :find, {}, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        response_complete? response
      end
      it "nil gets json-ld" do
        request.accept = nil
        ss = subject.send(:solr_searcher)
        allow(ss).to receive(:find).and_return(anno_graphs_array)
        get :find, {}, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        response_complete? response
      end
      it "*/* gets json-ld" do
        request.accept = "*/*"
        ss = subject.send(:solr_searcher)
        allow(ss).to receive(:find).and_return(anno_graphs_array)
        get :find, {}, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        response_complete? response
      end
      it "html uses view" do
        request.accept = "text/html"
        ss = subject.send(:solr_searcher)
        allow(ss).to receive(:find).and_return(anno_graphs_array)
        get :find, {}, format: nil
        expect(response.content_type).to eql("text/html")
        expect(response).to render_template(:find)
      end
      context 'multiple formats' do
        # rails will use them in order listed in the http accept header value.
        # also, "note that if browser is sending */* along with other values then Rails totally bails out and just returns Mime::HTML"
        #   http://blog.bigbinary.com/2010/11/23/mime-type-resolution-in-rails.html
        it 'uses first known format' do
          request.accept = "application/ld+json, text/x-json, application/json"
          ss = subject.send(:solr_searcher)
          allow(ss).to receive(:find).and_return(anno_graphs_array)
          get :find, {}, format: nil
          expect(response.content_type).to eql("application/ld+json")
          expect(response.body).to match json_regex
          response_complete? response
        end
      end
    end # response format

    context 'SearchError' do
      let(:triannon_err_msg) { "triannon msg" }

      context 'with Solr HTTP info' do
        let(:search_resp_code) { 409 }
        let(:search_resp_body) { "body of error resp from search server" }
        let(:search_error) { Triannon::SearchError.new(triannon_err_msg, search_resp_code, search_resp_body)}
        it "gives Solr's resp code" do
          ss = subject.send(:solr_searcher)
          allow(ss).to receive(:find).and_raise(search_error)
          get :find, {'targetUri' => "some.url.org"}
          expect(response.status).to eq search_resp_code
        end
        it "gives html response" do
          ss = subject.send(:solr_searcher)
          allow(ss).to receive(:find).and_raise(search_error)
          get :find, {'targetUri' => "some.url.org"}
          expect(response.content_type).to eql "text/html"
        end
        it "has useful info in the responose" do
          ss = subject.send(:solr_searcher)
          allow(ss).to receive(:find).and_raise(search_error)
          get :find, {'targetUri' => "some.url.org"}
          expect(response.body).to match search_resp_body
          expect(response.body).to match triannon_err_msg
        end
      end

      context 'no Solr HTTP info' do
        let(:search_error) { Triannon::SearchError.new(triannon_err_msg)}

        context 'with Solr HTTP info' do
          it "gives 400 resp code" do
            ss = subject.send(:solr_searcher)
            allow(ss).to receive(:find).and_raise(search_error)
            get :find, {'targetUri' => "some.url.org"}
            expect(response.status).to eq 400
          end
          it "gives html response" do
            ss = subject.send(:solr_searcher)
            allow(ss).to receive(:find).and_raise(search_error)
            get :find, {'targetUri' => "some.url.org"}
            expect(response.content_type).to eql "text/html"
          end
          it "has useful info in the responose" do
            ss = subject.send(:solr_searcher)
            allow(ss).to receive(:find).and_raise(search_error)
            get :find, {'targetUri' => "some.url.org"}
            expect(response.body).to match triannon_err_msg
          end
        end
      end

    end # SearchError

  end # GET find


end
