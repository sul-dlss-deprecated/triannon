require 'spec_helper'

describe Triannon::AnnotationsController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }
  let(:bookmark_anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("bookmark.json"), id: '123'}
  let(:body_chars_anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("body-chars.ttl"), id: '666' }

  # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
  json_regex = /\A\{.+\}\Z/m


  before(:each) do
    allow(Triannon::Annotation).to receive(:find).with('123').and_return(bookmark_anno)
    allow(Triannon::Annotation).to receive(:find).with('666').and_return(body_chars_anno)
  end

  it "should have an index" do
    a1 = Triannon::Annotation.new :id => 'abc'
    a2 = Triannon::Annotation.new :id => 'dce'
    allow(Triannon::Annotation).to receive(:all).and_return [a1, a2]
    get :index
  end

  context "#create" do
    it 'creates a new annotation from the body of the request' do
      ttl_data = Triannon.annotation_fixture("body-chars.ttl")
      post :create, ttl_data
      expect(response.status).to eq 302
    end
    
    it 'creates a new annotation from params from form' do
      ttl_data = Triannon.annotation_fixture("body-chars.ttl")
      post :create, :annotation => {:data => ttl_data}
      expect(response.status).to eq 302
    end

    it "renders 403 if Triannon::ExternalReferenceError raised during LdpCreator.create" do
      err_msg = "some error during LdpCreator.create"
      allow(Triannon::LdpCreator).to receive(:create).and_raise(Triannon::ExternalReferenceError, err_msg)
      post :create, "this string will be ignored so it doesn't matter"
      expect(response.status).to eq 403
      expect(response.body).to eql err_msg
    end
  end
  
  context '#show' do
    context 'jsonld_context param' do
      shared_examples_for 'jsonld_context respected' do | jsonld_context, format |
        it 'calls correct method in Triannon::Annotation model' do
          if !format || format.length == 0
            format = "application/ld+json"
          end
          @request.accept = format
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
          @request.accept = "application/ld+json"
          [bookmark_anno, body_chars_anno].each { |anno|  
            get :show, id: anno.id, jsonld_context: jsonld_context
            case jsonld_context
              when "iiif", "IIIF"
# FIXME:  these urls should be constants declared somewhere              
                expect(@response.body).to match("http://iiif.io/api/presentation/2/context.json")
                expect(@response.body).to match(/"on":/)
              when "oa", "OA"
                expect(@response.body).to match("http://www.w3.org/ns/oa.jsonld")
                expect(@response.body).to match(/"hasTarget":/)
            end
            expect(@response.content_type).to eql("application/ld+json")
            expect(@response.body).to match json_regex
            expect(@response.status).to eql(200)
          }
        end
      end
      
      context 'in path' do
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
          @request.accept = "application/ld+json"
          get :show, id: bookmark_anno.id, jsonld_context: 'foo'
          expect(@response.body).to match("http://www.w3.org/ns/oa.jsonld")
          expect(@response.body).to match(/"hasTarget":/)
          expect(@response.content_type).to eql("application/ld+json")
          expect(@response.body).to match json_regex
          expect(@response.status).to eql(200)
        end
        context 'pays attention to jsonld_context for all jsonld and json accept formats' do
          it_behaves_like 'jsonld_context respected', "iiif", "application/ld+json"
          it_behaves_like 'jsonld_context respected', "iiif", "application/json"
          it_behaves_like 'jsonld_context respected', "iiif", "text/x-json"
          it_behaves_like 'jsonld_context respected', "iiif", "application/jsonrequest"
          it_behaves_like 'jsonld_context respected', "oa", "application/ld+json"
          it_behaves_like 'jsonld_context respected', "oa", "application/json"
          it_behaves_like 'jsonld_context respected', "oa", "text/x-json"
          it_behaves_like 'jsonld_context respected', "oa", "application/jsonrequest"
        end
        it 'ignores jsonld_context for formats other than jsonld and json' do
          skip "test to be implemented"
          it_behaves_like 'accept header determines media type', ["application/x-turtle", "application/rdf+xml", ""]
        end
      end
      context 'as a user param' do
        it 'iiif value returns IIIF context jsonld' do
          skip "test to be implemented"
        end
        it 'IIIF value returns IIIF context jsonld' do
          skip "test to be implemented"
        end
        it 'oa value returns OAI context jsonld' do
          skip "test to be implemented"
        end
        it 'OA value returns OAI context jsonld' do
          skip "test to be implemented"
        end
        it 'returns OA when neither iiif or oa is param value and format is jsonld' do
          skip "test to be implemented"
        end
        it 'ignored when format is not json or jsonld' do
          skip "test to be implemented"
        end
      end
    end
    
    context "response format" do
      shared_examples_for 'accept header determines media type' do | mime_types, regex |
        mime_types.each { |mtype|
          it "#{mtype}" do
            @request.accept = mtype
            get :show, id: bookmark_anno.id
            expect(@response.content_type).to eql(mtype)
            expect(@response.body).to match(regex)
            expect(@response.status).to eql(200)
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
        @request.accept = ""
        get :show, id: bookmark_anno.id, format: nil
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
      it "nil gets json-ld" do
        @request.accept = nil
        get :show, id: bookmark_anno.id, format: nil
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
      it "*/* gets json-ld" do
        @request.accept = "*/*"
        get :show, id: bookmark_anno.id, format: nil
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
      it "html uses view" do
        @request.accept = "text/html"
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
          @request.accept = "application/ld+json, text/x-json, application/json"
          get :show, id: bookmark_anno.id
          expect(@response.content_type).to eql("application/ld+json")
          expect(@response.body).to match json_regex
          expect(@response.status).to eql(200)
        end
      end
    end # response format
    
  end # #show

end
