require 'spec_helper'

vcr_options = { :cassette_name => "controllers_annotations_index" }
describe Triannon::AnnotationsController, type: :controller, :vcr => vcr_options do

  routes { Triannon::Engine.routes }

  it "should have an index" do
    get :index
  end

  it "should have a show" do
    @annotation = Triannon::Annotation.create(data: Triannon.annotation_fixture("bookmark.json"))

    get :show, id: @annotation.id
    expect(assigns[:annotation]).to eq @annotation
  end

  context "show request's response format" do
    before(:each) do
      @annotation = Triannon::Annotation.create(data: Triannon.annotation_fixture("bookmark.json"))
    end
    shared_examples_for 'accept header determines media type' do | mime_types, regex | 
      mime_types.each { |mtype|  
        it "#{mtype}" do
          @request.accept = mtype
          get :show, id: @annotation.id
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
      it_behaves_like 'accept header determines media type', ["application/rdf+xml", "text/rdf+xml", "text/rdf", "application/xml", "text/xml"], /\A<.+>\Z/m
    end
    context "json" do
      # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
      it_behaves_like 'accept header determines media type', ["application/ld+json", "application/json", "text/x-json"], /\A\{.+\}\Z/m
    end
    it "empty string gets json-ld" do
      @request.accept = ""
      get :show, id: @annotation.id, format: nil
      expect(@response.content_type).to eql("application/ld+json") 
      expect(@response.body).to match(/\A\{.+\}\Z/m) # (Note: \A and \Z and m are needed instead of ^$ due to \n in data)
      expect(@response.status).to eql(200)
    end
    it "no format specified gets json-ld" do
      @request.accept = nil
      get :show, id: @annotation.id, format: nil
      expect(@response.content_type).to eql("application/ld+json") 
      expect(@response.body).to match(/\A\{.+\}\Z/m) # (Note: \A and \Z and m are needed instead of ^$ due to \n in data)
      expect(@response.status).to eql(200)
    end
    it "*/* format specified gets json-ld" do
      @request.accept = "*/*"
      get :show, id: @annotation.id, format: nil
      expect(@response.content_type).to eql("application/ld+json") 
      expect(@response.body).to match(/\A\{.+\}\Z/m) # (Note: \A and \Z and m are needed instead of ^$ due to \n in data)
      expect(@response.status).to eql(200)
    end
    it "html uses view" do
      @request.accept = "text/html"
      get :show, id: @annotation.id
      expect(response.content_type).to eql("text/html") 
      expect(response.status).to eql(200)
      expect(response).to render_template(:show)
    end
    context 'multiple formats' do
      it 'jsonld and json favors jsonld' do
        skip "to be implemented"
        @request.accept = ["application/json", "text/x-json", "application/ld+json"]
        get :show, id: @annotation.id
        expect(@response.content_type).to eql("application/ld+json") 
        expect(@response.body).to match(/\A\{.+\}\Z/m) # (Note: \A and \Z and m are needed instead of ^$ due to \n in data)
        expect(@response.status).to eql(200)
      end
      # ultimately the same (jsonld, json)
      # ultimately diff (json, ttl)
      it 'jsonld first' do
        skip "to be implemented"
      end
      it 'jsonld not first' do
        skip "to be implemented"
      end
      it 'jsonld missing' do
        skip "to be implemented"
      end
    end
  end
  
end
