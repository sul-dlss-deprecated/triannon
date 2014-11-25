require 'spec_helper'

describe Triannon::AnnotationsController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }
  let(:annotation) { Triannon::Annotation.new data: Triannon.annotation_fixture("bookmark.json"), id: '123'}

  # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
  json_regex = /\A\{.+\}\Z/m


  before(:each) do
    allow(Triannon::Annotation).to receive(:find).and_return(annotation)
  end

  it "should have an index" do
    a1 = Triannon::Annotation.new :id => 'abc'
    a2 = Triannon::Annotation.new :id => 'dce'
    allow(Triannon::Annotation).to receive(:all).and_return [a1, a2]
    get :index
  end

  it "should have a show" do
    get :show, id: annotation.id
    expect(assigns[:annotation]).to eq annotation
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

  context "show request's response format" do

    shared_examples_for 'accept header determines media type' do | mime_types, regex |
      mime_types.each { |mtype|
        it "#{mtype}" do
          @request.accept = mtype
          get :show, id: annotation.id
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
      get :show, id: annotation.id, format: nil
      expect(@response.content_type).to eql("application/ld+json")
      expect(@response.body).to match json_regex
      expect(@response.status).to eql(200)
    end
    it "nil gets json-ld" do
      @request.accept = nil
      get :show, id: annotation.id, format: nil
      expect(@response.content_type).to eql("application/ld+json")
      expect(@response.body).to match json_regex
      expect(@response.status).to eql(200)
    end
    it "*/* gets json-ld" do
      @request.accept = "*/*"
      get :show, id: annotation.id, format: nil
      expect(@response.content_type).to eql("application/ld+json")
      expect(@response.body).to match json_regex
      expect(@response.status).to eql(200)
    end
    it "html uses view" do
      @request.accept = "text/html"
      get :show, id: annotation.id
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
        get :show, id: annotation.id
        expect(@response.content_type).to eql("application/ld+json")
        expect(@response.body).to match json_regex
        expect(@response.status).to eql(200)
      end
    end
  end

end
