require 'spec_helper'

describe Triannon::AnnotationsController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  # regex: \A and \Z and m are needed instead of ^$ due to \n in data)
  json_regex = /\A\{.+\}\Z/m

  context '#show' do
    before(:all) do
      @root_container = 'anno_controller_show_specs'
      vcr_cassette_name = "Triannon_AnnotationsController/_show/before_spec"
      create_root_container(@root_container, vcr_cassette_name)
    end
    after(:all) do
      ldp_testing_container_urls = ["#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"]
      vcr_cassette_name = "Triannon_AnnotationsController/_show/after_spec"
      delete_test_objects(ldp_testing_container_urls, [], @root_container, vcr_cassette_name)
    end

    let(:bookmark_anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("bookmark.json"), id: '123'}
    let(:body_chars_anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("body-chars.ttl"), id: '666' }
    before(:each) do
      allow(Triannon::Annotation).to receive(:find).with('123', @root_container).and_return(bookmark_anno)
      allow(Triannon::Annotation).to receive(:find).with('666', @root_container).and_return(body_chars_anno)
    end

    context 'non-existent id' do
      let(:fake_id) { "foo" }
      before(:each) do
        allow(Triannon::Annotation).to receive(:find).with(fake_id, @root_container).and_raise(
          Triannon::LDPStorageError.new("Not Found", 404, 
            "<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html;
              charset=ISO-8859-1\"/>\n<title>Error 404 Not Found</title>\n</head>\n<body><h2>HTTP
              ERROR 404</h2>\n<p>Problem accessing /fedora/rest/anno/foo. Reason:\n<pre>
              Not Found</pre></p><hr /><br/>\n</body>\n</html>\n"))
      end

      it "gives 404 resp code" do
        get :show, anno_root: @root_container, id: fake_id
        expect(response.status).to eq 404
      end
      it "gives html response" do
        get :show, anno_root: @root_container, id: fake_id
        expect(response.content_type).to eql "text/html"
      end
      it "has useful info in the responose" do
        get :show, anno_root: @root_container, id: fake_id
        expect(response.body).to match fake_id
        expect(response.body).to match "404"
        expect(response.body).to match "Not Found"
      end
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
              get :show, anno_root: @root_container, id: bookmark_anno.id, jsonld_context: jsonld_context
              expect(model).to receive(:jsonld_iiif)
              get :show, anno_root: @root_container, id: body_chars_anno.id, jsonld_context: jsonld_context
            when "oa", "OA"
              expect(model).to receive(:jsonld_oa)
              get :show, anno_root: @root_container, id: bookmark_anno.id, jsonld_context: jsonld_context
              expect(model).to receive(:jsonld_oa)
              get :show, anno_root: @root_container, id: body_chars_anno.id, jsonld_context: jsonld_context
          end
        end
        it "response has correct context" do
          request.accept = "application/ld+json"
          [bookmark_anno, body_chars_anno].each { |anno|
            get :show, anno_root: @root_container, id: anno.id, jsonld_context: jsonld_context
            case jsonld_context
              when "iiif", "IIIF"
                expect(response.body).to match(OA::Graph::IIIF_CONTEXT_URL)
                expect(response.body).to match(/"on":/)
              when "oa", "OA"
                expect(response.body).to match(OA::Graph::OA_DATED_CONTEXT_URL)
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
        get :show, anno_root: @root_container, id: bookmark_anno.id, jsonld_context: 'foo'
        expect(response.body).to match(OA::Graph::OA_DATED_CONTEXT_URL)
        expect(response.body).to match(/"hasTarget":/)
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      it 'returns OA context jsonld when context is missing in path' do
        request.accept = "application/ld+json"
        get :show, anno_root: @root_container, id: bookmark_anno.id, jsonld_context: ''
        expect(response.body).to match(OA::Graph::OA_DATED_CONTEXT_URL)
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
            get :show, anno_root: @root_container, id: anno.id, jsonld_context: 'iiif'
            expect(response.body).not_to match(OA::Graph::IIIF_CONTEXT_URL)
            expect(response.body).not_to match(/"on":/)
            expect(response.body).not_to match json_regex
            expect(response.content_type).to eql(mime_type)
            expect(response.status).to eql(200)
          }
        }
      end
    end # jsonld_context param

    context "response format" do
      shared_examples_for 'accept header determines media type' do | mime_types, regex |
        mime_types.each { |mtype|
          it "#{mtype}" do
            request.accept = mtype
            get :show, anno_root: @root_container, id: bookmark_anno.id
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
        get :show, anno_root: @root_container, id: bookmark_anno.id, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      it "nil gets json-ld" do
        request.accept = nil
        get :show, anno_root: @root_container, id: bookmark_anno.id, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      it "*/* gets json-ld" do
        request.accept = "*/*"
        get :show, anno_root: @root_container, id: bookmark_anno.id, format: nil
        expect(response.content_type).to eql("application/ld+json")
        expect(response.body).to match json_regex
        expect(response.status).to eql(200)
      end
      it "html uses view" do
        request.accept = "text/html"
        get :show, anno_root: @root_container, id: bookmark_anno.id
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
          get :show, anno_root: @root_container, id: bookmark_anno.id
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
            get :show, anno_root: @root_container, id: bookmark_anno.id
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
            it_behaves_like 'creates anno successfully', "application/ld+json", OA::Graph::OA_DATED_CONTEXT_URL
          end
          context 'oa generic' do
            it_behaves_like 'creates anno successfully', "application/ld+json", OA::Graph::OA_CONTEXT_URL, OA::Graph::OA_DATED_CONTEXT_URL
          end
          context 'iiif' do
            it_behaves_like 'creates anno successfully', "application/ld+json", OA::Graph::IIIF_CONTEXT_URL
          end
          it "missing context returns oa dated" do
            request.accept = "application/ld+json"
            get :show, anno_root: @root_container, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/ld+json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match OA::Graph::OA_DATED_CONTEXT_URL
          end
          it "unrecognized context returns oa dated" do
            request.accept = "application/ld+json; profile=\"http://not.a.real.doctor.com/\""
            get :show, anno_root: @root_container, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/ld+json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match OA::Graph::OA_DATED_CONTEXT_URL
          end
        end
        context 'json (be nice and pay attention to profile)' do
          context 'oa dated' do
            it_behaves_like 'creates anno successfully', "application/json", OA::Graph::OA_DATED_CONTEXT_URL
          end
          context 'oa generic' do
            it_behaves_like 'creates anno successfully', "text/x-json", OA::Graph::OA_CONTEXT_URL, OA::Graph::OA_DATED_CONTEXT_URL
          end
          context 'iiif' do
            it_behaves_like 'creates anno successfully', "application/jsonrequest", OA::Graph::IIIF_CONTEXT_URL
          end
          it "missing context returns oa dated" do
            request.accept = "application/json"
            get :show, anno_root: @root_container, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match OA::Graph::OA_DATED_CONTEXT_URL
          end
        end
        it "context specified for non-json returns non-json" do
          request.accept = "application/x-turtle; profile=\"#{OA::Graph::IIIF_CONTEXT_URL}\""
          get :show, anno_root: @root_container, id: bookmark_anno.id
          expect(response.status).to eq 200
          expect(response.content_type).to eql("application/x-turtle")
          expect(response.body).to match /\.\Z/  # \Z is needed instead of $ due to \n in data)
          expect(response.body).to match "kq131cs7229"
          expect(response.body).not_to match OA::Graph::IIIF_CONTEXT_URL
        end
      end
      context 'Link header specifies context URL' do
        shared_examples_for 'creates anno successfully' do | mime_type, context_url, result_url |
          it "link type specified" do
            request.accept = "#{mime_type}"
            request.headers["Link"] = "#{context_url}; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
            get :show, anno_root: @root_container, id: bookmark_anno.id
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
            get :show, anno_root: @root_container, id: bookmark_anno.id
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
            it_behaves_like 'creates anno successfully', "application/json", OA::Graph::OA_DATED_CONTEXT_URL
          end
          context 'oa generic' do
            it_behaves_like 'creates anno successfully', "text/x-json", OA::Graph::OA_CONTEXT_URL, OA::Graph::OA_DATED_CONTEXT_URL
          end
          context 'iiif' do
            it_behaves_like 'creates anno successfully', "application/jsonrequest", OA::Graph::IIIF_CONTEXT_URL
          end
          context "unrecognized context returns oa dated" do
            it_behaves_like 'creates anno successfully', "application/jsonrequest", "http://context.unknown.org", OA::Graph::OA_DATED_CONTEXT_URL
          end
          context "missing context returns oa dated" do
            it_behaves_like 'creates anno successfully', "text/x-json", "", OA::Graph::OA_DATED_CONTEXT_URL
          end
          it "no link header returns oa dated" do
            request.accept = "application/json"
            get :show, anno_root: @root_container, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match OA::Graph::OA_DATED_CONTEXT_URL
          end
        end
        context 'jsonld (be nice and pay attention to link)' do
          context 'oa dated' do
            it_behaves_like 'creates anno successfully', "application/ld+json", OA::Graph::OA_DATED_CONTEXT_URL
          end
          context 'oa generic' do
            it_behaves_like 'creates anno successfully', "application/ld+json", OA::Graph::OA_CONTEXT_URL, OA::Graph::OA_DATED_CONTEXT_URL
          end
          context 'iiif' do
            it_behaves_like 'creates anno successfully', "application/ld+json", OA::Graph::IIIF_CONTEXT_URL
          end
          context "unrecognized context returns oa dated" do
            it_behaves_like 'creates anno successfully', "application/ld+json", "http://context.unknown.org", OA::Graph::OA_DATED_CONTEXT_URL
          end
          context "missing context returns oa dated" do
            it_behaves_like 'creates anno successfully', "application/ld+json", "", OA::Graph::OA_DATED_CONTEXT_URL
          end
          it "no link header returns oa dated" do
            request.accept = "application/ld+json"
            get :show, anno_root: @root_container, id: bookmark_anno.id
            expect(response.status).to eq 200
            expect(response.content_type).to eql("application/ld+json")
            expect(response.body).to match json_regex
            expect(response.body).to match "kq131cs7229"
            expect(response.body).to match OA::Graph::OA_DATED_CONTEXT_URL
          end
        end
        it "context specified for non-json returns non-json" do
          request.accept = "application/x-turtle"
          request.headers["Link"] = "#{OA::Graph::IIIF_CONTEXT_URL}; rel=\"http://www.w3.org/ns/json-ld#context\""
          get :show, anno_root: @root_container, id: bookmark_anno.id
          expect(response.status).to eq 200
          expect(response.content_type).to eql("application/x-turtle")
          expect(response.body).to match /\.\Z/  # \Z is needed instead of $ due to \n in data)
          expect(response.body).to match "kq131cs7229"
          expect(response.body).not_to match OA::Graph::IIIF_CONTEXT_URL
        end
      end
    end # jsonld_context via HTTP header

  end # #show

end
