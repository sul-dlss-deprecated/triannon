require 'spec_helper'

describe Triannon::LdpWriter, :vcr do

  before(:all) do
    @cont_urls_to_delete_after_testing = []
    @ldp_url = Triannon.config[:ldp]['url']
    @ldp_url.chop! if @ldp_url.end_with?('/')
    @uber_cont = Triannon.config[:ldp]['uber_container'].strip
    @uber_cont = @uber_cont[1..-1] if @uber_cont.start_with?('/')
    @uber_cont.chop! if @uber_cont.end_with?('/')
    @uber_root_url = "#{@ldp_url}/#{@uber_cont}"
    @root_container = 'ldpw_spec'
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
    @root_url = "#{@uber_root_url}/#{@root_container}"
    begin
      @outer_cassette_name = "Triannon_LdpWriter/before_ldp_writer_spec"
      VCR.insert_cassette(@cassette_name)
      Triannon::LdpWriter.create_basic_container(nil, @uber_cont)
      Triannon::LdpWriter.create_basic_container(@uber_cont, @root_container)
    rescue Faraday::ConnectionFailed
      # probably here due to vcr cassette
    end
  end
  after(:all) do
    @cont_urls_to_delete_after_testing << "#{@root_url}"
    @cont_urls_to_delete_after_testing.each { |cont_url|
      begin
        if Triannon::LdpWriter.container_exist?(cont_url.split(@uber_root_url).last)
          Triannon::LdpWriter.delete_container cont_url
          Faraday.new(url: "#{cont_url}/fcr:tombstone").delete
        end
      rescue Faraday::ConnectionFailed
        # probably here due to vcr cassette
      end
    }
    VCR.eject_cassette(@outer_cassette_name)
  end
  let(:conn) { Faraday.new(url: @uber_root_url) }

  context "#create_base" do
    it 'creates new annotation as a child of anno_root_container' do
      anno_id = @ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{anno_id}"
      resp = conn.get do |req|
        req.url "#{@root_container}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      uri = RDF::URI.new(@root_url)
      expect(g.query([uri, RDF.type, RDF::Vocab::LDP.BasicContainer]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::LDP.contains, RDF::URI.new("#{@root_url}/#{anno_id}")]).size).to eql 1
    end
    it 'LDP store creates Basic Container for the annotation and returns id' do
      anno_id = @ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{anno_id}"
      resp = conn.get do |req|
        req.url "#{@root_container}/#{anno_id}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      uri = RDF::URI.new("#{@root_url}/#{anno_id}")
      expect(g.query([uri, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([uri, RDF.type, RDF::Vocab::LDP.BasicContainer]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    end
    it 'IIIF anno has sc:painting motivation' do
      iiif_anno = Triannon::Annotation.new data: '
        {
          "@context":"http://iiif.io/api/presentation/2/context.json",
          "@type":"oa:Annotation",
          "motivation":"sc:painting",
          "resource":{
            "@type":"cnt:ContentAsText",
            "chars":"Here starts book one...",
            "format":"text/plain",
            "language":"en"
          },
          "on":"http://www.example.org/iiif/book1/canvas/p1#xywh=100,150,500,25"
        }'
      my_ldpw = Triannon::LdpWriter.new iiif_anno, @root_container
      base_pid = my_ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{base_pid}"
      resp = conn.get do |req|
        req.url "#{@root_container}/#{base_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      uri = RDF::URI.new("#{@root_url}/#{base_pid}")
      expect(g.query([uri, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::OA.motivatedBy, RDF::Vocab::IIIF.painting]).size).to eql 1
    end
    it 'keeps multiple motivations if present' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "motivatedBy": [
          "oa:moderating",
          "oa:tagging"
        ],
        "hasBody": {
          "@id": "http://dbpedia.org/resource/Banhammer",
          "@type": "oa:SemanticTag"
        },
        "hasTarget": "http://purl.stanford.edu/kq131cs7229"
      }'
      my_ldpw = Triannon::LdpWriter.new my_anno, @root_container
      new_pid = my_ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{new_pid}"
      resp = conn.get do |req|
        req.url "#{@root_container}/#{new_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      uri = RDF::URI.new("#{@root_url}/#{new_pid}")
      expect(g.query([uri, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.moderating]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.tagging]).size).to eql 1
    end
    it 'posts provenance if present' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "motivatedBy": "oa:commenting",
        "annotatedAt": "2014-09-03T17:16:13Z",
        "annotatedBy": {
          "@id": "mailto:azaroth42@gmail.com",
          "@type": "foaf:Person",
          "name": "Rob Sanderson"
        },
        "serializedAt": "2014-09-03T17:16:13Z",
        "serializedBy": {
          "@type": "prov:SoftwareAgent",
          "name": "Annotation Factory"
        },
        "hasBody": {
          "@type": [
            "cnt:ContentAsText",
            "dctypes:Text"
          ],
          "chars": "I love this!"
        },
        "hasTarget": "http://purl.stanford.edu/kq131cs7229"
      }'
      my_ldpw = Triannon::LdpWriter.new my_anno, @root_container
      new_pid = my_ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{new_pid}"
      resp = conn.get do |req|
        req.url "#{@root_container}/#{new_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      uri = RDF::URI.new("#{@root_url}/#{new_pid}")
      expect(g.query([uri, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
      xsd_dt_literal_opts = {datatype: RDF::XSD.dateTimeStamp}
      expect(g.query([uri, RDF::Vocab::OA.annotatedAt, RDF::Literal.new("2014-09-03T17:16:13Z", xsd_dt_literal_opts)]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::OA.annotatedBy, nil]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::OA.serializedAt, RDF::Literal.new("2014-09-03T17:16:13Z", xsd_dt_literal_opts)]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::OA.serializedBy, nil]).size).to eql 1
    end
    it "raises Triannon::ExternalReferenceError if incoming anno graph contains RDF::Triannon.externalReference in target" do
      my_anno = Triannon::Annotation.new data: '
      <> a <http://www.w3.org/ns/oa#Annotation>;
         <http://www.w3.org/ns/oa#hasTarget> <http://our.fcrepo.org/anno/target_container>;
         <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#bookmarking> .

      <http://our.fcrepo.org/anno/target_container> <http://triannon.stanford.edu/ns/externalReference> <http://cool.resource.org> .'

      my_ldpw = Triannon::LdpWriter.new my_anno, @root_container
      expect{my_ldpw.create_base}.to raise_error(Triannon::ExternalReferenceError, "Incoming annotations may not have http://triannon.stanford.edu/ns/externalReference as a predicate.")
    end
    it "raises Triannon::ExternalReferenceError if incoming anno graph contains RDF::Triannon.externalReference in body" do
      my_anno = Triannon::Annotation.new data: '
      <> a <http://www.w3.org/ns/oa#Annotation>;
         <http://www.w3.org/ns/oa#hasBody> <http://our.fcrepo.org/anno/body_container>;
         <http://www.w3.org/ns/oa#hasTarget> <http://cool.resource.org>;
         <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#bookmarking> .

      <http://our.fcrepo.org/anno/body_container> <http://triannon.stanford.edu/ns/externalReference> <http://anno.body.org> .'
      my_ldpw = Triannon::LdpWriter.new my_anno, @root_container
      expect{my_ldpw.create_base}.to raise_error(Triannon::ExternalReferenceError, "Incoming annotations may not have http://triannon.stanford.edu/ns/externalReference as a predicate.")
    end
    it "raises Triannon::ExternalReferenceError if incoming anno graph has id for outer node" do
      my_anno = Triannon::Annotation.new data: '
      <http://some.org/id> a <http://www.w3.org/ns/oa#Annotation>;
         <http://www.w3.org/ns/oa#hasTarget> <http://cool.resource.org>;
         <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#bookmarking> .'
      my_ldpw = Triannon::LdpWriter.new my_anno, @root_container
      expect{my_ldpw.create_base}.to raise_error(Triannon::ExternalReferenceError, "Incoming new annotations may not have an existing id (yet).")
    end
    it 'raises Triannon::LDPContainerError if anno_root_container is nil' do
      my_ldpw = Triannon::LdpWriter.new(@anno, nil)
      expect{my_ldpw.create_base}.to raise_error(Triannon::LDPContainerError, "Annotations must be created in a root container.")
    end
    it 'raises Triannon::LDPContainerError if anno_root_container is empty string' do
      my_ldpw = Triannon::LdpWriter.new(@anno, "")
      expect{my_ldpw.create_base}.to raise_error(Triannon::LDPContainerError, "Annotations must be created in a root container.")
    end
    it "raises Triannon::MissingLDPContainerError if anno_root_container doesn't exist" do
      cont = "not_there"
      my_ldpw = Triannon::LdpWriter.new(@anno, cont)
      expect{my_ldpw.create_base}.to raise_error(Triannon::MissingLDPContainerError, "Annotation root container #{cont} doesn't exist.")
    end
  end # create_base

  context "#create_body_container" do
    it 'calls #create_direct_container with hasBody' do
      expect(@ldpw).to receive(:create_direct_container).with(RDF::Vocab::OA.hasBody)
      @ldpw.create_body_container
    end
    it 'LDP store creates retrievable LDP DirectContainer with correct member relationships' do
      @ldpw = Triannon::LdpWriter.new @anno, @root_container
      id = @ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{id}"
      @ldpw.create_body_container
      resp = conn.get do |req|
        req.url "#{@root_container}/#{id}/b"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      uri = RDF::URI.new("#{@root_url}/#{id}/b")
      expect(g.query([uri, RDF.type, RDF::Vocab::LDP.DirectContainer]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::LDP.membershipResource, RDF::URI.new("#{@root_url}/#{id}")]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::LDP.hasMemberRelation, RDF::Vocab::OA.hasBody]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::LDP.contains, nil]).size).to eql 0
    end
  end

  context "#create_target_container" do
    it 'calls #create_direct_container with hasTarget' do
      expect(@ldpw).to receive(:create_direct_container).with(RDF::Vocab::OA.hasTarget)
      @ldpw.create_target_container
    end
    it 'LDP store creates retrievable LDP DirectContainer with correct member relationships' do
      @ldpw = Triannon::LdpWriter.new @anno, @root_container
      id = @ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{id}"
      @ldpw.create_target_container
      resp = conn.get do |req|
        req.url "#{@root_container}/#{id}/t"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      uri = RDF::URI.new("#{@root_url}/#{id}/t")
      expect(g.query([uri, RDF.type, RDF::Vocab::LDP.DirectContainer]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::LDP.membershipResource, RDF::URI.new("#{@root_url}/#{id}")]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::LDP.hasMemberRelation, RDF::Vocab::OA.hasTarget]).size).to eql 1
      expect(g.query([uri, RDF::Vocab::LDP.contains, nil]).size).to eql 0
    end
  end

  context '#create_body_resources' do
    it "calls create_resources_in_container with hasBody predicate" do
      new_pid = @ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{new_pid}"
      @ldpw.create_body_container
      expect(@ldpw).to receive(:create_resources_in_container).with(RDF::Vocab::OA.hasBody)
      body_uuids = @ldpw.create_body_resources
    end
    context "after create_resources_in_container" do
      before(:all) do
        @cassette_name = "Triannon_LdpWriter/after_create_body_resources"
        VCR.insert_cassette(@cassette_name)
        my_ldpw = Triannon::LdpWriter.new @anno, @root_container
        @anno_id = my_ldpw.create_base
        @cont_urls_to_delete_after_testing << "#{@root_container}/#{@anno_id}"
        my_ldpw.create_body_container
        body_uuids = my_ldpw.create_body_resources
        expect(body_uuids.size).to eql 1
        @body_child_path = "#{@anno_id}/b/#{body_uuids[0]}"
        @body_child_url = "#{@root_url}/#{@body_child_path}"
      end 
      after(:all) do
        VCR.eject_cassette(@cassette_name)
      end
      it 'correct body content in new body child container' do
        resp = conn.get do |req|
          req.url "#{@root_container}/#{@body_child_path}"
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(@body_child_url), RDF.type, RDF::Vocab::LDP.RDFSource]).size).to eql 1
        expect(g.query([RDF::URI.new(@body_child_url), RDF.type, RDF::Vocab::LDP.BasicContainer]).size).to eql 1
        expect(g.query([RDF::URI.new(@body_child_url), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
        expect(g.query([RDF::URI.new(@body_child_url), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
        expect(g.query([RDF::URI.new(@body_child_url), RDF::Vocab::CNT.chars, "I love this!"]).size).to eql 1
      end
      it 'body container gets ldp:contains statement' do
        resp = conn.get do |req|
          req.url "#{@root_container}/#{@anno_id}/b"
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        body_cont_url = "#{@root_url}/#{@anno_id}/b"
        expect(g.query([RDF::URI.new(body_cont_url), RDF::Vocab::LDP.contains, RDF::URI.new(@body_child_url)]).size).to eql 1
      end
      it 'base container gets oa:hasBody statement' do
        resp = conn.get do |req|
          req.url "#{@root_container}/#{@anno_id}"
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        anno_url = "#{@root_url}/#{@anno_id}"
        expect(g.query([RDF::URI.new(anno_url), RDF::Vocab::OA.hasBody, RDF::URI.new(@body_child_url)]).size).to eql 1
      end
    end # after create_resources_in_container
  end # create_body_resources

  context '#create_target_resources' do
    it "calls create_resources_in_container with hasTarget predicate" do
      new_pid = @ldpw.create_base
      @ldpw.create_target_container
      expect(@ldpw).to receive(:create_resources_in_container).with(RDF::Vocab::OA.hasTarget)
      body_uuids = @ldpw.create_target_resources
    end
    context "after create_resources_in_container" do
      before(:all) do
        @cassette_name = "Triannon_LdpWriter/after_create_target_resources"
        VCR.insert_cassette(@cassette_name)
        my_ldpw = Triannon::LdpWriter.new @anno, @root_container
        @anno_id = my_ldpw.create_base
        @cont_urls_to_delete_after_testing << "#{@root_container}/#{@anno_id}"
        my_ldpw.create_target_container
        target_uuids = my_ldpw.create_target_resources
        expect(target_uuids.size).to eql 1
        @target_child_path = "#{@anno_id}/t/#{target_uuids[0]}"
        @target_child_url = "#{@root_url}/#{@target_child_path}"
      end
      after(:all) do
        VCR.eject_cassette(@cassette_name)
      end
      it 'correct target content in new target child container' do
        resp = conn.get do |req|
          req.url "#{@root_container}/#{@target_child_path}"
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(@target_child_url), RDF.type, RDF::Vocab::LDP.RDFSource]).size).to eql 1
        expect(g.query([RDF::URI.new(@target_child_url), RDF.type, RDF::Vocab::LDP.BasicContainer]).size).to eql 1
      end
      it 'target container gets ldp:contains statement' do
        resp = conn.get do |req|
          req.url "#{@root_container}/#{@anno_id}/t"
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        target_cont_url = "#{@root_url}/#{@anno_id}/t"
        expect(g.query([RDF::URI.new(target_cont_url), RDF::Vocab::LDP.contains, RDF::URI.new(@target_child_url)]).size).to eql 1
      end
      it 'base container gets oa:hasTarget statement' do
        resp = conn.get do |req|
          req.url "#{@root_container}/#{@anno_id}"
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        anno_url = "#{@root_url}/#{@anno_id}"
        expect(g.query([RDF::URI.new(anno_url), RDF::Vocab::OA.hasTarget, RDF::URI.new(@target_child_url)]).size).to eql 1
      end
    end # after create_resources_in_container
  end # create_target_resources

  context '#delete_containers' do
    it 'deletes the resource from the LDP store when id is full url' do
      ldpw = Triannon::LdpWriter.new @anno, @root_container
      ldp_id = ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{ldp_id}"
      
      expect(ldp_id).not_to match @root_url
      ldpw.delete_containers "#{@root_url}/#{ldp_id}"

      resp = conn.get do |req|
        req.url "#{@root_container}/#{ldp_id}"
      end
      expect(resp.status).to eq 410
    end
    it 'works when id is just anno id' do
      ldpw = Triannon::LdpWriter.new @anno, @root_container
      ldp_id = ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{ldp_id}"

      ldpw.delete_containers ldp_id

      resp = conn.get do |req|
        req.url "#{@root_container}/#{ldp_id}"
      end
      expect(resp.status).to eq 410
    end
    it 'works when id is anno root + anno id' do
      ldpw = Triannon::LdpWriter.new @anno, @root_container
      ldp_id = ldpw.create_base
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{ldp_id}"

      ldpw.delete_containers "#{@root_container}/#{ldp_id}"

      resp = conn.get do |req|
        req.url "#{@root_container}/#{ldp_id}"
      end
      expect(resp.status).to eq 410
    end

    it 'works with a String arg' do
      # see "deletes all child containers, recursively"
    end
    it 'works with Array arg' do
      # see "doesn't delete the parent container"
    end

    it "doesn't delete the parent container" do
      ldp_id = Triannon::LdpWriter.create_anno @anno, @root_container
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{ldp_id}"
      ldpw = Triannon::LdpWriter.new(nil, @root_container)

      # delete the body resources
      l = Triannon::LdpLoader.new ldp_id
      l.load_anno_container
      ldpw.delete_containers l.ldp_annotation.body_uris

      # ensure the body container still exists
      resp = conn.get do |req|
        req.url "#{@root_container}/#{ldp_id}/b"
      end
      expect(resp.status).to eql 200
      expect(resp.body).to match /hasMemberRelation.*hasBody/
    end
    it 'deletes all child containers, recursively' do
      ldp_id = Triannon::LdpWriter.create_anno @anno, @root_container
      @cont_urls_to_delete_after_testing << "#{@root_container}/#{kdo_id}"

      l = Triannon::LdpLoader.new ldp_id
      l.load_anno_container
      body_uris = l.ldp_annotation.body_uris
      expect(body_uris.size).to be > 0

      # delete body container
      ldpw = Triannon::LdpWriter.new(nil, @root_container)
      ldpw.delete_containers "#{@root_container}/#{ldp_id}/b"

      # ensure no body objects still exist
      body_uris.each { |body_ldp_uri|
        # get the ids of the body resources
        resp = conn.get do |req|
          req.url "#{@root_container}/#{body_ldp_uri}"
        end
        expect(resp.status == 404 || resp.status == 410).to be true
      }
    end

    context 'LDPStorageError' do
      it "raised with status code and body when LDP returns [404, 409, 412]" do
        container_id = "container_id"
        ldp_resp_body = "foo"
        [404, 409, 412].each { |status_code|
          ldp_resp = double()
          allow(ldp_resp).to receive(:body).and_return(ldp_resp_body)
          allow(ldp_resp).to receive(:status).and_return(status_code)
          my_conn = double()
          allow(my_conn).to receive(:delete).and_return(ldp_resp)

          writer = Triannon::LdpWriter.new @anno, @root_container
          allow(writer).to receive(:conn).and_return(my_conn)

          expect { writer.delete_containers([container_id]) }.to raise_error { |error|
            expect(error).to be_a Triannon::LDPStorageError
            expect(error.message).to eq "Unable to delete LDP container #{@root_container}/#{container_id}"
            expect(error.ldp_resp_status).to eq status_code
            expect(error.ldp_resp_body).to eq ldp_resp_body
          }
        }
      end
    end
  end # delete_containers

end
