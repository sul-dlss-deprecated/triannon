require 'spec_helper'

class RdfResponseFormatsTestController < ApplicationController
  include RdfResponseFormats
end

describe RdfResponseFormatsTestController, type: :controller do

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
        expect(controller.send(:context_url_from_accept)).to eq OA::Graph::OA_DATED_CONTEXT_URL
      end
      it 'oa generic' do
        request.accept = 'application/ld+json; profile="http://www.w3.org/ns/oa.jsonld"'
        expect(controller.send(:context_url_from_accept)).to eq OA::Graph::OA_CONTEXT_URL
      end
      it 'iiif' do
        request.accept = 'application/ld+json; profile="http://iiif.io/api/presentation/2/context.json"'
        expect(controller.send(:context_url_from_accept)).to eq OA::Graph::IIIF_CONTEXT_URL
      end
    end
    context 'json, accept profile' do
      it 'oa dated' do
        request.accept = 'application/json; profile="http://www.w3.org/ns/oa-context-20130208.json"'
        expect(controller.send(:context_url_from_accept)).to eq OA::Graph::OA_DATED_CONTEXT_URL
      end
      it 'oa generic' do
        request.accept = 'text/x-json; profile="http://www.w3.org/ns/oa.jsonld"'
        expect(controller.send(:context_url_from_accept)).to eq OA::Graph::OA_CONTEXT_URL
      end
      it 'iiif' do
        request.accept = 'application/jsonrequest; profile="http://iiif.io/api/presentation/2/context.json"'
        expect(controller.send(:context_url_from_accept)).to eq OA::Graph::IIIF_CONTEXT_URL
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
      expect(controller.send(:context_url_from_accept)).to eq OA::Graph::OA_DATED_CONTEXT_URL
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
        it_behaves_like "parses successfully", "application/json", OA::Graph::OA_DATED_CONTEXT_URL
        it_behaves_like "parses successfully", "text/x-json", OA::Graph::OA_DATED_CONTEXT_URL
        it_behaves_like "parses successfully", "application/jsonrequest", OA::Graph::OA_DATED_CONTEXT_URL
      end
      context 'oa generic' do
        it_behaves_like "parses successfully", "application/json", OA::Graph::OA_CONTEXT_URL
        it_behaves_like "parses successfully", "text/x-json", OA::Graph::OA_CONTEXT_URL
        it_behaves_like "parses successfully", "application/jsonrequest", OA::Graph::OA_CONTEXT_URL
      end
      context 'iiif' do
        it_behaves_like "parses successfully", "application/json", OA::Graph::IIIF_CONTEXT_URL
        it_behaves_like "parses successfully", "text/x-json", OA::Graph::IIIF_CONTEXT_URL
        it_behaves_like "parses successfully", "application/jsonrequest", OA::Graph::IIIF_CONTEXT_URL
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
        it_behaves_like "parses successfully", "application/ld+json", OA::Graph::OA_DATED_CONTEXT_URL
      end
      context 'oa generic' do
        it_behaves_like "parses successfully", "application/ld+json", OA::Graph::OA_CONTEXT_URL
      end
      context 'iiif' do
        it_behaves_like "parses successfully", "application/ld+json", OA::Graph::IIIF_CONTEXT_URL
      end
    end
    it 'non-json format gives nil' do
      request.accept = 'application/x-turtle'
      request.headers["Link"] = "#{OA::Graph::OA_CONTEXT_URL}; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
      expect(controller.send(:context_url_from_link)).to eq nil
    end
  end # context_url_from_accept

end