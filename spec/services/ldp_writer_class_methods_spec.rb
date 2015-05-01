require 'spec_helper'

describe Triannon::LdpWriter, :vcr do

  let(:anno) { Triannon::Annotation.new data: '
    <> a <http://www.w3.org/ns/oa#Annotation>;
       <http://www.w3.org/ns/oa#hasBody> [
         a <http://www.w3.org/2011/content#ContentAsText>,
           <http://purl.org/dc/dcmitype/Text>;
         <http://www.w3.org/2011/content#chars> "I love this!"
       ];
       <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>;
       <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#commenting> .' }
  let(:triannon_anno_container) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"}
  let(:conn) { Faraday.new(url: triannon_anno_container) }

  context 'class methods' do

    describe '*create_anno' do
      it 'calls create_base' do
        expect_any_instance_of(Triannon::LdpWriter).to receive(:create_base).and_call_original
        Triannon::LdpWriter.create_anno anno
      end
      it 'returns the pid of the annotation container in LDP store' do
        id = Triannon::LdpWriter.create_anno anno
        expect(id).to be_a String
        expect(id.size).to be > 10
        resp = conn.get do |req|
          req.url id
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        full_url = "#{triannon_anno_container}/#{id}"
        expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      end
      it 'does not create a body container if there are no bodies' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": "http://purl.stanford.edu/kq131cs7229"
        }'
        expect_any_instance_of(Triannon::LdpWriter).not_to receive(:create_body_container)
        Triannon::LdpWriter.create_anno my_anno
      end
      it 'creates a LDP resource for bodies ldp container at (id)/b' do
        pid = Triannon::LdpWriter.create_anno anno
        container_url = "#{triannon_anno_container}/#{pid}/b"
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
        Triannon::LdpWriter.create_anno anno
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
        id = Triannon::LdpWriter.create_anno my_anno
        container_url = "#{triannon_anno_container}/#{id}/b"
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
        Triannon::LdpWriter.create_anno anno
      end
      it 'creates a LDP resource for targets ldp container at (id)/t' do
        pid = Triannon::LdpWriter.create_anno anno
        container_url = "#{triannon_anno_container}/#{pid}/t"
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
        id = Triannon::LdpWriter.create_anno my_anno
        container_url = "#{triannon_anno_container}/#{id}/t"
        container_resp = conn.get do |req|
          req.url container_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(container_resp.body)
        expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, nil]).size).to eql 2
      end
      it "raises an exception if the create does not succeed" do
        allow_any_instance_of(Triannon::LdpWriter).to receive(:create_resource).and_raise("reason")
        expect { Triannon::LdpWriter.create anno }.to raise_error
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

      context '*delete_container' do
        it_behaves_like "ldp container deleted", :delete_container
      end
      context '*delete_anno' do
        it_behaves_like "ldp container deleted", :delete_anno
      end
    end

    context '#container_exist?' do
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

  end # class methods

end
