require 'spec_helper'

describe Triannon::AnnotationsController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }
  let(:bookmark_anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("bookmark.json"), id: '123'}
  let(:body_chars_anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("body-chars.ttl"), id: '666' }

  # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
  json_regex = /\A\{.+\}\Z/m

  it "should have an index" do
    a1 = Triannon::Annotation.new :id => 'abc'
    a2 = Triannon::Annotation.new :id => 'dce'
    allow(Triannon::Annotation).to receive(:all).and_return [a1, a2]
    get :index
  end

  context "#create" do
    let (:ttl_data) {Triannon.annotation_fixture("body-chars.ttl")}
    it 'creates a new annotation from the body of the request' do
      post :create, ttl_data
      expect(response.status).to eq 201
    end
    
    it 'creates a new annotation from params from form' do
      post :create, :annotation => {:data => ttl_data}
      expect(response.status).to eq 201
    end

    it "renders 403 if Triannon::ExternalReferenceError raised during LdpWriter.create_anno" do
      err_msg = "some error during LdpWriter.create_anno"
      allow(Triannon::LdpWriter).to receive(:create_anno).and_raise(Triannon::ExternalReferenceError, err_msg)
      post :create, ttl_data
      expect(response.status).to eq 403
      expect(response.body).to eql err_msg
    end
    
    context 'HTTP Content-Type header' do
      shared_examples_for 'header matches data' do | header_mimetype, data, from_xxx_method_sym |
        it "#{header_mimetype} specified and provided" do
          gg = RDF::Graph.new
          gg.send(from_xxx_method_sym, data)
          allow(RDF::Graph).to receive(:new).and_return(gg)
          expect_any_instance_of(RDF::Graph).to receive(from_xxx_method_sym).at_least(:once).and_return(gg)
          request.headers["Content-Type"] = header_mimetype
          post :create, data
          expect(response.status).to eq 201
        end
      end
      shared_examples_for 'header does NOT match data' do | header_mimetype, data, from_xxx_method_sym |
        it "#{header_mimetype} specified and NOT provided" do
          gg = RDF::Graph.new
          allow(RDF::Graph).to receive(:new) {gg}
          expect_any_instance_of(RDF::Graph).to receive(from_xxx_method_sym).at_least(:once)
          allow_any_instance_of(Triannon::Annotation).to receive(:solr_save) # avoid spec error
          request.headers["Content-Type"] = header_mimetype
          post :create, data
          expect(response.status).to eq 400
        end
      end

      # turtle
      %w{application/x-turtle text/turtle}.each { |mtype|
        it_behaves_like 'header matches data', mtype, Triannon.annotation_fixture("body-chars.ttl"), :from_ttl
      }
      it_behaves_like 'header does NOT match data', 'application/x-turtle', Triannon.annotation_fixture("body-chars.json"), :from_ttl

      # rdfxml
      %w{application/rdf+xml text/rdf+xml text/rdf}.each { |mtype|
        it_behaves_like 'header matches data', mtype, Triannon.annotation_fixture("body-chars.rdf"), :from_rdfxml
      }
      it_behaves_like 'header does NOT match data', 'application/rdf+xml', Triannon.annotation_fixture("body-chars.json"), :from_rdfxml
      # xml specified (but is rdf xml)
      %w{application/xml text/xml application/x-xml}.each { |mtype|
        it_behaves_like 'header matches data', mtype, Triannon.annotation_fixture("body-chars.rdf"), :from_rdfxml
      }

      # json - must be tested differently due to using inline context substitution for jsonld
      let(:jsonld_data) { Triannon.annotation_fixture("body-chars.json") }
      it "jsonld specified and matches data" do
        g = RDF::Graph.new.from_jsonld jsonld_data
        allow(RDF::Graph).to receive(:new).and_return(g)
        expect(JSON::LD::API).to receive(:toRdf).and_return(g)
        request.headers["Content-Type"] = "application/ld+json"
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "jsonld specified and NOT provided" do
        expect_any_instance_of(Triannon::Annotation).to receive(:jsonld_to_graph).at_least(:once)
        allow_any_instance_of(Triannon::Annotation).to receive(:solr_save) # avoid spec error
        request.headers["Content-Type"] = "application/ld+json"
        post :create, ttl_data
        expect(response.status).to eq 400
      end
      # I couldn't get the three tests below to run cleanly in a loop
      it "application/json specified for jsonld" do
        gg = RDF::Graph.new.from_jsonld(jsonld_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect(JSON::LD::API).to receive(:toRdf).and_return(gg)
        request.headers["Content-Type"] = "application/json"
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "text/x-json specified for jsonld" do
        gg = RDF::Graph.new.from_jsonld(jsonld_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect(JSON::LD::API).to receive(:toRdf).and_return(gg)
        request.headers["Content-Type"] = "text/x-json"
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "application/jsonrequest specified for jsonld" do
        gg = RDF::Graph.new.from_jsonld(jsonld_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect(JSON::LD::API).to receive(:toRdf).and_return(gg)
        request.headers["Content-Type"] = "application/jsonrequest"
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "unknown format gives 400" do
        request.headers["Content-Type"] = "application/foo"
        post :create, jsonld_data
        expect(response.status).to eq 400
      end
      it "unspecified Content-Type - tries to infer it jsonld" do
        gg = RDF::Graph.new.from_jsonld(jsonld_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect_any_instance_of(Triannon::Annotation).to receive(:jsonld_to_graph).and_return(gg)
        request.headers["Content-Type"] = nil
        post :create, jsonld_data
        expect(response.status).to eq 201
      end
      it "unspecified Content-Type - tries to infer it ttl" do
        gg = RDF::Graph.new.from_ttl(ttl_data)
        allow(RDF::Graph).to receive(:new).and_return(gg)
        expect_any_instance_of(Triannon::Annotation).to receive(:ttl_to_graph).and_return(gg)
        request.headers["Content-Type"] = nil
        post :create, ttl_data
        expect(response.status).to eq 201
      end
      context 'jsonld context' do
        context "NOT included in header" do
          shared_examples_for 'creates anno successfully' do | test_data |
            it "" do
              request.headers["Content-Type"] = "application/ld+json"
              request.headers["Accept"] = "application/ld+json"
              post :create, test_data
              expect(response.status).to eq 201
              expect(response.body).to match "I love this"
            end
          end
          context "oa generic uri inline" do
            it_behaves_like "creates anno successfully", Triannon.annotation_fixture("body-chars-generic-context.json")
          end
          context "oa dated uri inline" do
            it_behaves_like "creates anno successfully", Triannon.annotation_fixture("body-chars.json")
          end
          context "iiif uri inline" do
            it_behaves_like "creates anno successfully", Triannon.annotation_fixture("body-chars-plain-iiif.json")
          end
          it "raises 400 error when no context specified inline" do
            request.headers["Content-Type"] = "application/ld+json"
            post :create, Triannon.annotation_fixture("body-chars-no-context.json")
            expect(response.status).to eq 400
          end
        end # NOT included in header
      end # jsonld context
    end # HTTP Content-Type header

    context "response format" do
      shared_examples_for 'Accept header determines media type' do | mime_types, regex |
        mime_types.each { |mtype|
          it "#{mtype}" do
            request.accept = mtype
            request.headers["Content-Type"] = "application/ld+json"
            post :create, Triannon.annotation_fixture("body-chars.json")
            expect(response.content_type).to eql(mtype)
            expect(response.body).to match(regex)
            expect(response.body).to match "I love this"
            expect(response.status).to eql(201)
          end
        }
      end
      context "turtle" do
        # regex:  \Z is needed instead of $ due to \n in data)
        it_behaves_like 'Accept header determines media type', ["text/turtle", "application/x-turtle"], /\.\Z/
      end
      context "rdfxml" do
        # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
        it_behaves_like 'Accept header determines media type', ["application/rdf+xml", "text/rdf+xml", "text/rdf", "application/xml", "text/xml", "application/x-xml"], /\A<.+>\Z/m
      end
      context "json" do
        it_behaves_like 'Accept header determines media type', ["application/ld+json", "application/json", "text/x-json", "application/jsonrequest"], json_regex
      end
      it "empty string gets json-ld" do
        request.accept = ""
        request.headers["Content-Type"] = "application/ld+json"
        post :create, Triannon.annotation_fixture("body-chars.json")
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.body).to match "I love this"
        expect(response.status).to eql(201)
      end
      it "nil gets json-ld" do
        request.accept = nil
        request.headers["Content-Type"] = "application/ld+json"
        post :create, Triannon.annotation_fixture("body-chars.json")
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.body).to match "I love this"
        expect(response.status).to eql(201)
      end
      it "*/* gets json-ld" do
        request.accept = "*/*"
        request.headers["Content-Type"] = "application/ld+json"
        post :create, Triannon.annotation_fixture("body-chars.json")
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.body).to match "I love this"
        expect(response.status).to eql(201)
      end
      it "html uses view" do
        request.accept = "text/html"
        request.headers["Content-Type"] = "application/ld+json"
        post :create, Triannon.annotation_fixture("body-chars.json")
        expect(response.content_type).to eql("text/html")
        expect(response.status).to eql(201)
        expect(response).to render_template(:show)
#        expect(response.body).to match "I love this"  # TODO:  need to address github issue #113  and get it to show anno in html for query
      end
      context 'multiple formats' do
        # rails will use them in order listed in the http accept header value.
        # also, "note that if browser is sending */* along with other values then Rails totally bails out and just returns Mime::HTML"
        #   http://blog.bigbinary.com/2010/11/23/mime-type-resolution-in-rails.html
        it 'uses first known format' do
          request.accept = "application/ld+json, text/x-json, application/json"
          request.headers["Content-Type"] = "application/ld+json"
          post :create, Triannon.annotation_fixture("body-chars.json")
          expect(response.content_type).to eql("application/ld+json")
          expect(response.body).to match json_regex
          expect(response.status).to eql(201)
        end
      end

      context 'jsonld context' do
        context 'Accept header profile specifies context URL' do
          shared_examples_for 'creates anno successfully' do | mime_type, context_url, result_url |
            it "" do
              request.accept = "#{mime_type}; profile=\"#{context_url}\""
              post :create, Triannon.annotation_fixture("bookmark.json")
              expect(response.status).to eq 201
              expect(response.content_type).to eql(mime_type)
              expect(response.body).to match json_regex
              expect(response.body).to match "kq131cs7229"
              if result_url
                expect(response.body).to match result_url
              else
                expect(response.body).to match context_url
              end
            end
          end
          context 'jsonld' do
            context 'oa dated' do
              it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context 'oa generic' do
              it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::OA_CONTEXT_URL, Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context 'iiif' do
              it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::IIIF_CONTEXT_URL
            end
            it "missing context returns oa dated" do
              request.accept = "application/ld+json"
              post :create, Triannon.annotation_fixture("bookmark.json")
              expect(response.status).to eq 201
              expect(response.content_type).to eql("application/ld+json")
              expect(response.body).to match json_regex
              expect(response.body).to match "kq131cs7229"
              expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            it "unrecognized context returns oa dated" do
              request.accept = "application/ld+json; profile=\"http://not.a.real.doctor.com/\""
              post :create, Triannon.annotation_fixture("bookmark.json")
              expect(response.status).to eq 201
              expect(response.content_type).to eql("application/ld+json")
              expect(response.body).to match json_regex
              expect(response.body).to match "kq131cs7229"
              expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
          end
          context 'json (be nice and pay attention to profile)' do
            context 'oa dated' do
              it_behaves_like 'creates anno successfully', "application/json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context 'oa generic' do
              it_behaves_like 'creates anno successfully', "text/x-json", Triannon::JsonldContext::OA_CONTEXT_URL, Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context 'iiif' do
              it_behaves_like 'creates anno successfully', "application/jsonrequest", Triannon::JsonldContext::IIIF_CONTEXT_URL
            end
            it "missing context returns oa dated" do
              request.accept = "application/json"
              post :create, Triannon.annotation_fixture("bookmark.json")
              expect(response.status).to eq 201
              expect(response.content_type).to eql("application/json")
              expect(response.body).to match json_regex
              expect(response.body).to match "kq131cs7229"
              expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
          end
          it "context specified for non-json returns non-json" do
            request.accept = "application/x-turtle; profile=\"#{Triannon::JsonldContext::IIIF_CONTEXT_URL}\""
            post :create, Triannon.annotation_fixture("body-chars.ttl")
            expect(response.status).to eq 201
            expect(response.content_type).to eql("application/x-turtle")
            expect(response.body).to match /\.\Z/  # \Z is needed instead of $ due to \n in data)
            expect(response.body).to match "kq131cs7229"
            expect(response.body).not_to match Triannon::JsonldContext::IIIF_CONTEXT_URL
          end
        end
        context 'Link header specifies context URL' do
          shared_examples_for 'creates anno successfully' do | mime_type, context_url, result_url |
            it "link type specified" do
              request.accept = "#{mime_type}"
              request.headers["Link"] = "#{context_url}; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
              post :create, Triannon.annotation_fixture("bookmark.json")
              expect(response.status).to eq 201
              expect(response.content_type).to eql(mime_type)
              expect(response.body).to match json_regex
              expect(response.body).to match "kq131cs7229"
              if result_url
                expect(response.body).to match result_url
              else
                expect(response.body).to match context_url
              end
            end
            it "link type not specified" do
              request.accept = "#{mime_type}"
              request.headers["Link"] = "#{context_url}; rel=\"http://www.w3.org/ns/json-ld#context\""
              post :create, Triannon.annotation_fixture("bookmark.json")
              expect(response.status).to eq 201
              expect(response.content_type).to eql(mime_type)
              expect(response.body).to match json_regex
              expect(response.body).to match "kq131cs7229"
              if result_url
                expect(response.body).to match result_url
              else
                expect(response.body).to match context_url
              end
            end
          end
          context 'json' do
            context 'oa dated' do
              it_behaves_like 'creates anno successfully', "application/json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context 'oa generic' do
              it_behaves_like 'creates anno successfully', "text/x-json", Triannon::JsonldContext::OA_CONTEXT_URL, Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context 'iiif' do
              it_behaves_like 'creates anno successfully', "application/jsonrequest", Triannon::JsonldContext::IIIF_CONTEXT_URL
            end
            context "unrecognized context returns oa dated" do
              it_behaves_like 'creates anno successfully', "application/jsonrequest", "http://context.unknown.org", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context "missing context returns oa dated" do
              it_behaves_like 'creates anno successfully', "text/x-json", "", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            it "no link header returns oa dated" do
              request.accept = "application/json"
              post :create, Triannon.annotation_fixture("bookmark.json")
              expect(response.status).to eq 201
              expect(response.content_type).to eql("application/json")
              expect(response.body).to match json_regex
              expect(response.body).to match "kq131cs7229"
              expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
          end
          context 'jsonld (be nice and pay attention to link)' do
            context 'oa dated' do
              it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context 'oa generic' do
              it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::OA_CONTEXT_URL, Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context 'iiif' do
              it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::IIIF_CONTEXT_URL
            end
            context "unrecognized context returns oa dated" do
              it_behaves_like 'creates anno successfully', "application/ld+json", "http://context.unknown.org", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            context "missing context returns oa dated" do
              it_behaves_like 'creates anno successfully', "application/ld+json", "", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
            it "no link header returns oa dated" do
              request.accept = "application/ld+json"
              post :create, Triannon.annotation_fixture("bookmark.json")
              expect(response.status).to eq 201
              expect(response.content_type).to eql("application/ld+json")
              expect(response.body).to match json_regex
              expect(response.body).to match "kq131cs7229"
              expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
            end
          end
          it "context specified for non-json returns non-json" do
            request.accept = "application/x-turtle"
            request.headers["Link"] = "#{Triannon::JsonldContext::IIIF_CONTEXT_URL}; rel=\"http://www.w3.org/ns/json-ld#context\""
            post :create, Triannon.annotation_fixture("body-chars.ttl")
            expect(response.status).to eq 201
            expect(response.content_type).to eql("application/x-turtle")
            expect(response.body).to match /\.\Z/  # \Z is needed instead of $ due to \n in data)
            expect(response.body).to match "kq131cs7229"
            expect(response.body).not_to match Triannon::JsonldContext::IIIF_CONTEXT_URL
          end
        end
      end # jsonld context
    end # response format

  end # #create
  
  context '#show' do
    before(:each) do
      allow(Triannon::Annotation).to receive(:find).with('123').and_return(bookmark_anno)
      allow(Triannon::Annotation).to receive(:find).with('666').and_return(body_chars_anno)
    end
    context 'jsonld_context param' do
      shared_examples_for 'jsonld_context respected' do | jsonld_context, format |
        it 'calls correct method in Triannon::Annotation model' do
          if !format || format.length == 0
            format = "application/ld+json"
          end
          request.accept = format
          model = double()
          allow(Triannon::Annotation).to receive(:find).and_return(model)
          case jsonld_context
            when "iiif", "IIIF"
              expect(model).to receive(:jsonld_iiif)
              get :show, id: bookmark_anno.id, jsonld_context: jsonld_context
              expect(model).to receive(:jsonld_iiif)
              get :show, id: body_chars_anno.id, jsonld_context: jsonld_context
            when "oa", "OA"
              expect(model).to receive(:jsonld_oa)
              get :show, id: bookmark_anno.id, jsonld_context: jsonld_context
              expect(model).to receive(:jsonld_oa)
              get :show, id: body_chars_anno.id, jsonld_context: jsonld_context
          end
        end
        it "response has correct context" do
          request.accept = "application/ld+json"
          [bookmark_anno, body_chars_anno].each { |anno|  
            get :show, id: anno.id, jsonld_context: jsonld_context
            case jsonld_context
              when "iiif", "IIIF"
                expect(response.body).to match(Triannon::JsonldContext::IIIF_CONTEXT_URL)
                expect(response.body).to match(/"on":/)
              when "oa", "OA"
                expect(response.body).to match(Triannon::JsonldContext::OA_DATED_CONTEXT_URL)
                expect(response.body).to match(/"hasTarget":/)
            end
            expect(response.content_type).to eql("application/ld+json")
            expect(response.body).to match json_regex
            expect(response.status).to eql(200)
          }
        end
      end
    
      context "iiif" do
        it_behaves_like 'jsonld_context respected', "iiif"
      end
      context "IIIF" do
        it_behaves_like 'jsonld_context respected', "IIIF"
      end
      context "oa" do
        it_behaves_like 'jsonld_context respected', "oa"
      end
      context "OA" do
        it_behaves_like 'jsonld_context respected', "OA"
      end
      it 'returns OA context jsonld when neither iiif or oa is in path' do
        request.accept = "application/ld+json"
        get :show, id: bookmark_anno.id, jsonld_context: 'foo'
        expect(response.body).to match(Triannon::JsonldContext::OA_DATED_CONTEXT_URL)
        expect(response.body).to match(/"hasTarget":/)
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      it 'returns OA context jsonld when context is missing in path' do
        request.accept = "application/ld+json"
        get :show, id: bookmark_anno.id, jsonld_context: ''
        expect(response.body).to match(Triannon::JsonldContext::OA_DATED_CONTEXT_URL)
        expect(response.body).to match(/"hasTarget":/)
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      context 'pays attention to jsonld_context for all jsonld and json accept formats' do
        it_behaves_like 'jsonld_context respected', "iiif", "application/ld+json"
        it_behaves_like 'jsonld_context respected', "iiif", "application/json"
        it_behaves_like 'jsonld_context respected', "iiif", "text/x-json"
        it_behaves_like 'jsonld_context respected', "iiif", "application/jsonrequest"
        it_behaves_like 'jsonld_context respected', "iiif", ""
        it_behaves_like 'jsonld_context respected', "oa", "application/ld+json"
        it_behaves_like 'jsonld_context respected', "oa", "application/json"
        it_behaves_like 'jsonld_context respected', "oa", "text/x-json"
        it_behaves_like 'jsonld_context respected', "oa", "application/jsonrequest"
        it_behaves_like 'jsonld_context respected', "oa", ""
      end
      it 'ignores jsonld_context for formats other than jsonld and json' do
        ["application/x-turtle", "application/rdf+xml"].each { |mime_type|  
          request.accept = mime_type
          [bookmark_anno, body_chars_anno].each { |anno|  
            get :show, id: anno.id, jsonld_context: 'iiif'
            expect(response.body).not_to match(Triannon::JsonldContext::IIIF_CONTEXT_URL)
            expect(response.body).not_to match(/"on":/)
            expect(response.body).not_to match json_regex
            expect(response.content_type).to eql(mime_type)
            expect(response.status).to eql(200)
          }
        }
      end
    end
    
    context "response format" do
      shared_examples_for 'accept header determines media type' do | mime_types, regex |
        mime_types.each { |mtype|
          it "#{mtype}" do
            request.accept = mtype
            get :show, id: bookmark_anno.id
            expect(response.content_type).to eql mtype
            expect(response.body).to match regex
            expect(response.body).to match "kq131cs7229"
            expect(response.status).to eq 200
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
        get :show, id: bookmark_anno.id, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      it "nil gets json-ld" do
        request.accept = nil
        get :show, id: bookmark_anno.id, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      it "*/* gets json-ld" do
        request.accept = "*/*"
        get :show, id: bookmark_anno.id, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      it "html uses view" do
        request.accept = "text/html"
        get :show, id: bookmark_anno.id
        expect(response.content_type).to eql("text/html")
        expect(response.status).to eql(200)
        expect(response).to render_template(:show)
      end
      context 'multiple formats' do
        # rails will use them in order listed in the http accept header value.
        # also, "note that if browser is sending */* along with other values then Rails totally bails out and just returns Mime::HTML"
        #   http://blog.bigbinary.com/2010/11/23/mime-type-resolution-in-rails.html
        it 'uses first known format' do
          request.accept = "application/ld+json, text/x-json, application/json"
          get :show, id: bookmark_anno.id
          expect(response.content_type).to eql("application/ld+json")
          expect(response.body).to match json_regex
          expect(response.status).to eql(200)
        end
      end
    end # response format
    
    context 'jsonld context' do
      context 'Accept header profile specifies context URL' do
        shared_examples_for 'creates anno successfully' do | mime_type, context_url, result_url |
          it "" do
            request.accept = "#{mime_type}; profile=\"#{context_url}\""
            get :show, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql(mime_type)
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            if result_url
              expect(response.body).to match result_url
            else
              expect(response.body).to match context_url
            end
          end
        end
        context 'jsonld' do
          context 'oa dated' do
            it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context 'oa generic' do
            it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::OA_CONTEXT_URL, Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context 'iiif' do
            it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::IIIF_CONTEXT_URL
          end
          it "missing context returns oa dated" do
            request.accept = "application/ld+json"
            get :show, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/ld+json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          it "unrecognized context returns oa dated" do
            request.accept = "application/ld+json; profile=\"http://not.a.real.doctor.com/\""
            get :show, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/ld+json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
        end
        context 'json (be nice and pay attention to profile)' do
          context 'oa dated' do
            it_behaves_like 'creates anno successfully', "application/json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context 'oa generic' do
            it_behaves_like 'creates anno successfully', "text/x-json", Triannon::JsonldContext::OA_CONTEXT_URL, Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context 'iiif' do
            it_behaves_like 'creates anno successfully', "application/jsonrequest", Triannon::JsonldContext::IIIF_CONTEXT_URL
          end
          it "missing context returns oa dated" do
            request.accept = "application/json"
            get :show, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
        end
        it "context specified for non-json returns non-json" do
          request.accept = "application/x-turtle; profile=\"#{Triannon::JsonldContext::IIIF_CONTEXT_URL}\""
          get :show, id: bookmark_anno.id
          expect(response.status).to eq 200
          expect(response.content_type).to eql("application/x-turtle")
          expect(response.body).to match /\.\Z/  # \Z is needed instead of $ due to \n in data)
          expect(response.body).to match "kq131cs7229"
          expect(response.body).not_to match Triannon::JsonldContext::IIIF_CONTEXT_URL
        end
      end
      context 'Link header specifies context URL' do
        shared_examples_for 'creates anno successfully' do | mime_type, context_url, result_url |
          it "link type specified" do
            request.accept = "#{mime_type}"
            request.headers["Link"] = "#{context_url}; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
            get :show, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql(mime_type)
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            if result_url
              expect(response.body).to match result_url
            else
              expect(response.body).to match context_url
            end
          end
          it "link type not specified" do
            request.accept = "#{mime_type}"
            request.headers["Link"] = "#{context_url}; rel=\"http://www.w3.org/ns/json-ld#context\""
            get :show, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql(mime_type)
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            if result_url
              expect(response.body).to match result_url
            else
              expect(response.body).to match context_url
            end
          end
        end
        context 'json' do
          context 'oa dated' do
            it_behaves_like 'creates anno successfully', "application/json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context 'oa generic' do
            it_behaves_like 'creates anno successfully', "text/x-json", Triannon::JsonldContext::OA_CONTEXT_URL, Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context 'iiif' do
            it_behaves_like 'creates anno successfully', "application/jsonrequest", Triannon::JsonldContext::IIIF_CONTEXT_URL
          end
          context "unrecognized context returns oa dated" do
            it_behaves_like 'creates anno successfully', "application/jsonrequest", "http://context.unknown.org", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context "missing context returns oa dated" do
            it_behaves_like 'creates anno successfully', "text/x-json", "", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          it "no link header returns oa dated" do
            request.accept = "application/json"
            get :show, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
        end
        context 'jsonld (be nice and pay attention to link)' do
          context 'oa dated' do
            it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context 'oa generic' do
            it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::OA_CONTEXT_URL, Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context 'iiif' do
            it_behaves_like 'creates anno successfully', "application/ld+json", Triannon::JsonldContext::IIIF_CONTEXT_URL
          end
          context "unrecognized context returns oa dated" do
            it_behaves_like 'creates anno successfully', "application/ld+json", "http://context.unknown.org", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          context "missing context returns oa dated" do
            it_behaves_like 'creates anno successfully', "application/ld+json", "", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
          it "no link header returns oa dated" do
            request.accept = "application/ld+json"
            get :show, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/ld+json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match Triannon::JsonldContext::OA_DATED_CONTEXT_URL
          end
        end
        it "context specified for non-json returns non-json" do
          request.accept = "application/x-turtle"
          request.headers["Link"] = "#{Triannon::JsonldContext::IIIF_CONTEXT_URL}; rel=\"http://www.w3.org/ns/json-ld#context\""
          get :show, id: bookmark_anno.id
          expect(response.status).to eq 200
          expect(response.content_type).to eql("application/x-turtle")
          expect(response.body).to match /\.\Z/  # \Z is needed instead of $ due to \n in data)
          expect(response.body).to match "kq131cs7229"
          expect(response.body).not_to match Triannon::JsonldContext::IIIF_CONTEXT_URL
        end
      end
    end

  end # #show

  context '#destroy' do
    it "returns 204 status code for successful delete" do
      anno = Triannon::Annotation.new({:data => Triannon.annotation_fixture("body-chars.ttl")})
      anno_id = anno.save
      my_anno = Triannon::Annotation.find(anno_id)
      delete :destroy, :id => anno_id
      expect(response.status).to eq 204
    end
  end

  context '#mime_type_from_accept' do
    let(:jsonld_mimetype) {"application/ld+json"}
    let(:json_mimetype) {"text/x-json"}
    let(:ttl_mimetype) {"application/x-turtle"}
    it "jsonld with profile specified" do
      request.accept = "#{jsonld_mimetype}; profile=\"http://www.w3.org/ns/oa.jsonld\""
      expect(controller.send(:mime_type_from_accept, jsonld_mimetype)).to eq jsonld_mimetype
    end
    it "jsonld without profile specified" do
      request.accept = jsonld_mimetype
      expect(controller.send(:mime_type_from_accept, jsonld_mimetype)).to eq jsonld_mimetype
    end
    it 'json with profile specified' do
      request.accept = "#{json_mimetype}; profile=\"http://www.w3.org/ns/oa.jsonld\""
      expect(controller.send(:mime_type_from_accept, ["application/json", "text/x-json", "application/jsonrequest"])).to eq json_mimetype
    end
    it 'non-jsonld with profile specified' do
      request.accept = "#{ttl_mimetype}; profile=\"http://www.w3.org/ns/oa.jsonld\""
      expect(controller.send(:mime_type_from_accept, ["application/x-turtle", "text/turtle"])).to eq ttl_mimetype
    end
    it 'non-jsonld without profile' do
      request.accept = ttl_mimetype
      expect(controller.send(:mime_type_from_accept, ["application/x-turtle", "text/turtle"])).to eq ttl_mimetype
    end
    context 'multiple formats specified' do
      it 'with jsonld with profile' do
        request.accept = "#{jsonld_mimetype}; profile=\"http://www.w3.org/ns/oa.jsonld\", #{json_mimetype}, application/json"
        expect(controller.send(:mime_type_from_accept, jsonld_mimetype)).to eq jsonld_mimetype
      end
      it 'with json with profile' do
        request.accept = "#{json_mimetype}; profile=\"http://www.w3.org/ns/oa.jsonld\", #{json_mimetype}, application/json"
        expect(controller.send(:mime_type_from_accept, ["application/json", "text/x-json", "application/jsonrequest"])).to eq json_mimetype
      end
      it 'wth non-jsonld with profile' do
        request.accept = "#{ttl_mimetype}; profile=\"http://www.w3.org/ns/oa.jsonld\", text/html"
        expect(controller.send(:mime_type_from_accept, ["application/x-turtle", "text/turtle"])).to eq ttl_mimetype
      end
      it 'without profile' do
        request.accept = "#{jsonld_mimetype}, text/x-json, application/json"
        expect(controller.send(:mime_type_from_accept, jsonld_mimetype)).to eq jsonld_mimetype
      end
    end
  end # mime_type_from_accept

  context '#context_url_from_accept' do
    context 'jsonld' do
      it 'oa dated' do
        request.accept = 'application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"'
        expect(controller.send(:context_url_from_accept)).to eq Triannon::JsonldContext::OA_DATED_CONTEXT_URL
      end
      it 'oa generic' do
        request.accept = 'application/ld+json; profile="http://www.w3.org/ns/oa.jsonld"'
        expect(controller.send(:context_url_from_accept)).to eq Triannon::JsonldContext::OA_CONTEXT_URL
      end
      it 'iiif' do
        request.accept = 'application/ld+json; profile="http://iiif.io/api/presentation/2/context.json"'
        expect(controller.send(:context_url_from_accept)).to eq Triannon::JsonldContext::IIIF_CONTEXT_URL
      end
    end
    context 'json, accept profile' do
      it 'oa dated' do
        request.accept = 'application/json; profile="http://www.w3.org/ns/oa-context-20130208.json"'
        expect(controller.send(:context_url_from_accept)).to eq Triannon::JsonldContext::OA_DATED_CONTEXT_URL
      end
      it 'oa generic' do
        request.accept = 'text/x-json; profile="http://www.w3.org/ns/oa.jsonld"'
        expect(controller.send(:context_url_from_accept)).to eq Triannon::JsonldContext::OA_CONTEXT_URL
      end
      it 'iiif' do
        request.accept = 'application/jsonrequest; profile="http://iiif.io/api/presentation/2/context.json"'
        expect(controller.send(:context_url_from_accept)).to eq Triannon::JsonldContext::IIIF_CONTEXT_URL
      end
    end
    it 'non-jsonld format gives nil' do
      request.accept = 'application/x-turtle; profile="http://www.w3.org/ns/oa.jsonld"'
      expect(controller.send(:context_url_from_accept)).to eq nil
    end
    it 'no profile specified gives nil' do
      request.accept = 'application/ld+json'
      expect(controller.send(:context_url_from_accept)).to eq nil
    end
    it "missing quotes around profile value works" do
      request.accept = 'application/ld+json; profile=http://www.w3.org/ns/oa-context-20130208.json'
      expect(controller.send(:context_url_from_accept)).to eq Triannon::JsonldContext::OA_DATED_CONTEXT_URL
    end
    it "unrecognized context_url gives nil" do
      request.accept = 'application/ld+json; profile=http://unknown.context.org'
      expect(controller.send(:context_url_from_accept)).to eq nil
    end
  end # context_url_from_accept

  context '#context_url_from_link' do
    shared_examples_for "parses successfully" do | mime_type, context_url|
      it "link type specified" do
        request.accept = mime_type
        request.headers["Link"] = "#{context_url}; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
        expect(controller.send(:context_url_from_link)).to eq context_url
      end
      it "link type not specified" do
        request.accept = mime_type
        request.headers["Link"] = "#{context_url}; rel=\"http://www.w3.org/ns/json-ld#context\""
        expect(controller.send(:context_url_from_link)).to eq context_url
      end
    end
    context 'json' do
      context 'oa dated' do
        it_behaves_like "parses successfully", "application/json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
        it_behaves_like "parses successfully", "text/x-json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
        it_behaves_like "parses successfully", "application/jsonrequest", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
      end
      context 'oa generic' do
        it_behaves_like "parses successfully", "application/json", Triannon::JsonldContext::OA_CONTEXT_URL
        it_behaves_like "parses successfully", "text/x-json", Triannon::JsonldContext::OA_CONTEXT_URL
        it_behaves_like "parses successfully", "application/jsonrequest", Triannon::JsonldContext::OA_CONTEXT_URL
      end
      context 'iiif' do
        it_behaves_like "parses successfully", "application/json", Triannon::JsonldContext::IIIF_CONTEXT_URL
        it_behaves_like "parses successfully", "text/x-json", Triannon::JsonldContext::IIIF_CONTEXT_URL
        it_behaves_like "parses successfully", "application/jsonrequest", Triannon::JsonldContext::IIIF_CONTEXT_URL
      end
      it 'unrecognized context_url specified gives nil' do
        request.accept = 'application/ld+json'
        request.headers["Link"] = "http://context.unknown.org; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
        expect(controller.send(:context_url_from_link)).to eq nil
      end
      it 'no context_url specified gives nil' do
        request.accept = 'application/ld+json'
        request.headers["Link"] = "rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
        expect(controller.send(:context_url_from_link)).to eq nil
      end
      it 'no Link header gives nil' do
        request.accept = 'application/ld+json'
        expect(controller.send(:context_url_from_link)).to eq nil
      end
    end
    context 'jsonld, accept link' do
      context 'oa dated' do
        it_behaves_like "parses successfully", "application/ld+json", Triannon::JsonldContext::OA_DATED_CONTEXT_URL
      end
      context 'oa generic' do
        it_behaves_like "parses successfully", "application/ld+json", Triannon::JsonldContext::OA_CONTEXT_URL
      end
      context 'iiif' do
        it_behaves_like "parses successfully", "application/ld+json", Triannon::JsonldContext::IIIF_CONTEXT_URL
      end
    end
    it 'non-json format gives nil' do
      request.accept = 'application/x-turtle'
      request.headers["Link"] = "#{Triannon::JsonldContext::OA_CONTEXT_URL}; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
      expect(controller.send(:context_url_from_link)).to eq nil
    end
  end # context_url_from_accept
end
