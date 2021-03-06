require 'spec_helper'

describe Triannon::LdpWriter, :vcr do

  before(:all) do
    @root_container = 'ldpwclassspec'
    @uber_root_url = "#{spec_ldp_url}/#{spec_uber_cont}"
    @root_url = "#{@uber_root_url}/#{@root_container}"
    @ldp_testing_container_urls = []
    vcr_cassette_name = "Triannon_LdpWriter/class_methods/before_ldp_writer_spec"
    create_root_container(@root_container, vcr_cassette_name)
    @anno = Triannon::Annotation.new data: '
      <> a <http://www.w3.org/ns/oa#Annotation>;
         <http://www.w3.org/ns/oa#hasBody> [
           a <http://www.w3.org/2011/content#ContentAsText>,
             <http://purl.org/dc/dcmitype/Text>;
           <http://www.w3.org/2011/content#chars> "I love this!"
         ];
         <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>;
         <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#commenting> .'
    @ldpw = Triannon::LdpWriter.new @anno, @root_container, 'foo'
  end
  after(:all) do
    @ldp_testing_container_urls << @root_url
    vcr_cassette_name = "Triannon_LdpWriter/class_methods/after_ldp_writer_spec"
    delete_test_objects(@ldp_testing_container_urls, [], @root_container, vcr_cassette_name)
  end
  let(:conn) { Faraday.new(url: @uber_root_url) }

  context 'class methods' do

    describe '.create_anno' do
      it 'calls create_base' do
        expect_any_instance_of(Triannon::LdpWriter).to receive(:create_base).and_call_original
        id = Triannon::LdpWriter.create_anno(@anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{id}"
      end
      it 'returns the pid of the annotation container in LDP store' do
        id = Triannon::LdpWriter.create_anno(@anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{id}"
        expect(id).to be_a String
        expect(id.size).to be > 10
        resp = conn.get do |req|
          req.url "#{@root_container}/#{id}"
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        full_url = "#{@root_url}/#{id}"
        expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      end
      it 'does not create a body container if there are no bodies' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": "http://purl.stanford.edu/kq131cs7229"
        }'
        expect_any_instance_of(Triannon::LdpWriter).not_to receive(:create_body_container)
        id = Triannon::LdpWriter.create_anno(my_anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{id}"
      end
      it 'creates a LDP resource for bodies ldp container at (id)\/b' do
        pid = Triannon::LdpWriter.create_anno(@anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{pid}"
        container_url = "#{@root_url}/#{pid}/b"
        container_resp = conn.get do |req|
          req.url container_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(container_resp.body)
        expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, nil]).size).to eql 1
      end
      it 'calls create_body_container and create_body_resources if there are bodies' do
        expect_any_instance_of(Triannon::LdpWriter).to receive(:create_body_container).and_call_original
        expect_any_instance_of(Triannon::LdpWriter).to receive(:create_body_resources)
        id = Triannon::LdpWriter.create_anno(@anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{id}"
      end
      it 'creates a single body container with multiple resources if there are multiple bodies' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "motivatedBy": "oa:commenting",
          "hasBody": [
            {
              "@type": [
                "cnt:ContentAsText",
                "dctypes:Text"
              ],
              "chars": "I love this!"
            },
            {
              "@id": "http://dbpedia.org/resource/Love",
              "@type": "oa:SemanticTag"
            }
          ]
        }'
        id = Triannon::LdpWriter.create_anno(my_anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{id}"
        container_url = "#{@root_url}/#{id}/b"
        container_resp = conn.get do |req|
          req.url container_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(container_resp.body)
        expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, nil]).size).to eql 2
      end
      it 'calls create_target_container and create_target_resource' do
        expect_any_instance_of(Triannon::LdpWriter).to receive(:create_target_container).and_call_original
        expect_any_instance_of(Triannon::LdpWriter).to receive(:create_target_resources)
        id = Triannon::LdpWriter.create_anno(@anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{id}"
      end
      it 'creates a LDP resource for targets ldp container at (id)\/t' do
        pid = Triannon::LdpWriter.create_anno(@anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{pid}"
        container_url = "#{@root_url}/#{pid}/t"
        container_resp = conn.get do |req|
          req.url container_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(container_resp.body)
        expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, nil]).size).to eql 1
      end
      it 'creates a single target container with multiple resources if there are multiple targets' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": [
            "http://purl.stanford.edu/kq131cs7229",
            "http://purl.stanford.edu/oo000oo1234"
          ]
        }'
        id = Triannon::LdpWriter.create_anno(my_anno, @root_container)
        @ldp_testing_container_urls << "#{@root_url}/#{id}"
        container_url = "#{@root_url}/#{id}/t"
        container_resp = conn.get do |req|
          req.url container_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(container_resp.body)
        expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, nil]).size).to eql 2
      end
      it "raises an exception if the create does not succeed" do
        allow_any_instance_of(Triannon::LdpWriter).to receive(:create_resource).and_raise("reason")
        expect { Triannon::LdpWriter.create @anno }.to raise_error
      end
    end # *create_anno

    context "deleting" do
      shared_examples_for 'ldp container deleted' do | method_name |
        it 'calls instance method delete_containers' do
          ldp_id = "foo"
          expect_any_instance_of(Triannon::LdpWriter).to receive(:delete_containers).with(ldp_id)
          Triannon::LdpWriter.send(method_name, ldp_id)
        end
      end

      context '.delete_container' do
        it_behaves_like "ldp container deleted", :delete_container
      end
      context '.delete_anno' do
        it_behaves_like "ldp container deleted", :delete_anno
      end
    end

    context '.container_exist?' do
      it 'true for http status 200' do
        resp = double()
        allow(resp).to receive(:status).and_return(200)
        conn = double()
        allow(conn).to receive(:head).and_return(resp)
        allow(Faraday).to receive(:new).and_return(conn)
        expect(Triannon::LdpWriter.container_exist?('ignored')).to be true
      end
      it 'true for existing container' do
        expect(Triannon::LdpWriter.container_exist?(Triannon.config[:ldp]['uber_container'])).to be true
      end
      it 'false for http status 404' do
        resp = double()
        allow(resp).to receive(:status).and_return(404)
        conn = double()
        allow(conn).to receive(:head).and_return(resp)
        allow(Faraday).to receive(:new).and_return(conn)
        expect(Triannon::LdpWriter.container_exist?('ignored')).to be false
      end
      it 'false for non-existent container' do
        expect(Triannon::LdpWriter.container_exist?('zzzyyyxxx')).to be false
      end
      it 'appends the path param to config[:ldp]["url"]' do
        path_param = "arbitrary"
        expect(Faraday).to receive(:new).with(url: "#{Triannon.config[:ldp]['url']}/#{path_param}").and_call_original
        Triannon::LdpWriter.container_exist?(path_param)
      end
      it 'avoids double slash if slash at end of ldp base url' do
        url_ends_w_slash = "http://somewhere.org/"
        config = { ldp: {'url' => url_ends_w_slash} }
        allow(Triannon).to receive(:config).and_return(config)
        path_param = "arbitrary"
        expect(Faraday).to receive(:new).with(url: "#{Triannon.config[:ldp]['url']}#{path_param}").and_call_original
        Triannon::LdpWriter.container_exist?(path_param)
      end
      it 'avoids double slash if slash at beginning of path' do
        path_param = "/arbitrary"
        expect(Faraday).to receive(:new).with(url: "#{Triannon.config[:ldp]['url']}#{path_param}").and_call_original
        Triannon::LdpWriter.container_exist?(path_param)
      end
    end

    context '.create_basic_container' do
      before(:all) do
        @created_before_slug = 'created_before'
        vcr_cassette_name = "Triannon_LdpWriter/class_methods/_create_basic_container/before_spec"
        create_root_container(@created_before_slug, vcr_cassette_name)
        @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}/#{@created_before_slug}"
      end
      it "creates container if it doesn't already exist" do
        slug = 'whee'
        allow(STDOUT).to receive(:puts)
        expect(Triannon::LdpWriter.create_basic_container("#{spec_uber_cont}/#{@root_container}", slug)).to eq true
        assert_basic_container("#{spec_uber_cont}/#{@root_container}/#{slug}")

        @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}/#{slug}"
      end
      it 'returns true and prints a message to STDOUT if it creates container' do
        slug = 'stdout-test'
        expect(STDOUT).to receive(:puts).with("Created Basic Container #{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}/#{slug}")
        expect(Triannon::LdpWriter.create_basic_container("#{spec_uber_cont}/#{@root_container}", slug)).to be true
        assert_basic_container("#{spec_uber_cont}/#{@root_container}/#{slug}")

        @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}/#{slug}"
      end
      it 'returns false and prints a message if container already exists' do
        expect(STDOUT).to receive(:puts).with("Container #{spec_ldp_url}/#{spec_uber_cont}/#{@created_before_slug} already exists.")
        expect(Triannon::LdpWriter.create_basic_container(spec_uber_cont, @created_before_slug)).to be false
      end
      it "prints message to STDOUT with err info if it doesn't create container" do
        allow(Triannon::LdpWriter).to receive(:container_exist?).and_return(false)
        resp = double()
        allow(resp).to receive(:status).and_return(500)
        allow(resp).to receive(:body).and_return("")
        conn = double()
        allow(conn).to receive(:post).and_return(resp)
        allow(Faraday).to receive(:new).and_return(conn)
        slug = "ignored"
        expect(STDOUT).to receive(:puts).with(a_string_starting_with("Unable to create Basic Container #{spec_ldp_url}/#{spec_uber_cont}/#{slug}"))
        expect(Triannon::LdpWriter.create_basic_container(spec_uber_cont, slug)).to be false
      end
      context "avoids double slash in url" do
        before(:each) do
          # mock method calls to Faraday::Connection and Faraday::Response
          @resp = double("faraday response")
          allow(@resp).to receive(:status)
          allow(@resp).to receive(:body)
          @fday = double("faraday connection")
          allow(@fday).to receive(:post).and_return(@resp)
        end
        it 'ldp base url ends with slash' do
          url_ends_w_slash = "http://somewhere.org/"
          config = { ldp: {'url' => url_ends_w_slash} }
          allow(Triannon).to receive(:config).and_return(config)
          parent_path = "arbitrary"
          slug = "ignored"
          expect(Faraday).to receive(:new).with(url: "#{Triannon.config[:ldp]['url']}#{parent_path}").and_return(@fday)
          allow(Triannon::LdpWriter).to receive(:container_exist?).and_return(false)
          allow(STDOUT).to receive(:puts)
          Triannon::LdpWriter.create_basic_container(parent_path, slug)
        end
        it 'parent path starts with slash' do
          parent_path = "/arbitrary"
          slug = "ignored"
          expect(Faraday).to receive(:new).with(url: "#{spec_ldp_url}#{parent_path}").and_return(@fday)
          allow(Triannon::LdpWriter).to receive(:container_exist?).and_return(false)
          allow(STDOUT).to receive(:puts)
          Triannon::LdpWriter.create_basic_container(parent_path, slug)
        end
        it 'parent path ends with slash' do
          parent_path = "arbitrary/"
          slug = "ignored"
          expect(Faraday).to receive(:new).with(url: "#{spec_ldp_url}/#{parent_path.chop}").and_return(@fday)
          allow(Triannon::LdpWriter).to receive(:container_exist?).and_return(false)
          allow(STDOUT).to receive(:puts)
          Triannon::LdpWriter.create_basic_container(parent_path, slug)
        end
        it 'slug starts with slash' do
          slug = "/initial_slash"
          allow(STDOUT).to receive(:puts)
          Triannon::LdpWriter.create_basic_container(spec_uber_cont, slug)
          assert_basic_container(spec_uber_cont + slug)
          expect(Triannon::LdpWriter.container_exist?("#{spec_uber_cont}/#{slug}")).to be false

          @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}#{slug}"
        end
      end
      it 'parent path missing nil or empty:  creates container directly under ldp base url' do
        slug = "missing_parent_path"
        allow(STDOUT).to receive(:puts)
        Triannon::LdpWriter.create_basic_container(nil, slug)
        assert_basic_container(slug)
        expect(Triannon::LdpWriter.container_exist?("#{spec_uber_cont}/#{slug}")).to be false

        @ldp_testing_container_urls << "#{spec_ldp_url}/#{slug}"
      end
      it 'slug is nil' do
        allow(STDOUT).to receive(:puts).with("create_basic_container called with nil or empty slug, parent_path 'ignored'")
        expect(Triannon::LdpWriter.create_basic_container("ignored", nil)).to be false
      end
      it 'slug is empty' do
        allow(STDOUT).to receive(:puts).with("create_basic_container called with nil or empty slug, parent_path 'ignored'")
        expect(Triannon::LdpWriter.create_basic_container("ignored", "")).to be false
      end

      # assert that param path is for a Basic Container in LDP Storage
      def assert_basic_container path
        container_url = "#{Triannon.config[:ldp]['url']}/#{path}"
        conn = Faraday.new url: container_url
        resp = conn.get do |req|
          req.headers['Accept'] = 'application/x-turtle'
        end
        expect(resp.status).to eq 200
        g = RDF::Graph.new.from_ttl resp.body

        q = RDF::Query.new
        q << [RDF::URI.new(container_url), RDF.type, RDF::Vocab::LDP.Container]
        expect(g.query(q).size).to eq 1
        q = RDF::Query.new
        q << [RDF::URI.new(container_url), RDF.type, RDF::Vocab::LDP.BasicContainer]
        expect(g.query(q).size).to eq 1

        # the following are all properties of Direct Containers so should be absent
        q = RDF::Query.new
        q << [RDF::URI.new(container_url), RDF.type, RDF::Vocab::LDP.DirectContainer]
        expect(g.query(q).size).to eq 0
        q = RDF::Query.new
        q << [RDF::URI.new(container_url), RDF::Vocab::LDP.hasMemberRelation, nil]
        expect(g.query(q).size).to eq 0
        q = RDF::Query.new
        q << [RDF::URI.new(container_url), RDF::Vocab::LDP.membershipResource, nil]
        expect(g.query(q).size).to eq 0
      end
    end

  end # class methods

end
