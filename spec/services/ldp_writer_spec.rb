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
  let(:ldpw) { Triannon::LdpWriter.new anno, 'foo' }
  let(:conn) { Faraday.new(:url => Triannon.config[:ldp_url]) }

  context "#create_base" do
    it 'LDP store creates retrievable object representing the annotation and returns id' do
      new_pid = ldpw.create_base
      resp = conn.get do |req|
        req.url new_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{new_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
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
      my_ldpw = Triannon::LdpWriter.new iiif_anno
      base_pid = my_ldpw.create_base
      resp = conn.get do |req|
        req.url base_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{base_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.motivatedBy, RDF::IIIFPresentation.painting]).size).to eql 1
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
      my_ldpw = Triannon::LdpWriter.new my_anno
      new_pid = my_ldpw.create_base
      resp = conn.get do |req|
        req.url new_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{new_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.moderating]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.tagging]).size).to eql 1
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
      my_ldpw = Triannon::LdpWriter.new my_anno
      new_pid = my_ldpw.create_base
      resp = conn.get do |req|
        req.url new_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{new_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.annotatedAt, "2014-09-03T17:16:13Z"]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.annotatedBy, nil]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.serializedAt, "2014-09-03T17:16:13Z"]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.serializedBy, nil]).size).to eql 1
    end
    it "raises Triannon::ExternalReferenceError if incoming anno graph contains RDF::Triannon.externalReference in target" do
      my_anno = Triannon::Annotation.new data: '
      <> a <http://www.w3.org/ns/oa#Annotation>;
         <http://www.w3.org/ns/oa#hasTarget> <http://our.fcrepo.org/anno/target_container>;
         <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#bookmarking> .

      <http://our.fcrepo.org/anno/target_container> <http://triannon.stanford.edu/ns/externalReference> <http://cool.resource.org> .'

      my_ldpw = Triannon::LdpWriter.new my_anno
      expect{my_ldpw.create_base}.to raise_error(Triannon::ExternalReferenceError, "Incoming annotations may not have http://triannon.stanford.edu/ns/externalReference as a predicate.")
    end
    it "raises Triannon::ExternalReferenceError if incoming anno graph contains RDF::Triannon.externalReference in body" do
      my_anno = Triannon::Annotation.new data: '
      <> a <http://www.w3.org/ns/oa#Annotation>;
         <http://www.w3.org/ns/oa#hasBody> <http://our.fcrepo.org/anno/body_container>;
         <http://www.w3.org/ns/oa#hasTarget> <http://cool.resource.org>;
         <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#bookmarking> .

      <http://our.fcrepo.org/anno/body_container> <http://triannon.stanford.edu/ns/externalReference> <http://anno.body.org> .'
      my_ldpw = Triannon::LdpWriter.new my_anno
      expect{my_ldpw.create_base}.to raise_error(Triannon::ExternalReferenceError, "Incoming annotations may not have http://triannon.stanford.edu/ns/externalReference as a predicate.")
    end
    it "raises Triannon::ExternalReferenceError if incoming anno graph has id for outer node" do
      my_anno = Triannon::Annotation.new data: '
      <http://some.org/id> a <http://www.w3.org/ns/oa#Annotation>;
         <http://www.w3.org/ns/oa#hasTarget> <http://cool.resource.org>;
         <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#bookmarking> .'
      my_ldpw = Triannon::LdpWriter.new my_anno
      expect{my_ldpw.create_base}.to raise_error(Triannon::ExternalReferenceError, "Incoming new annotations may not have an existing id (yet).")
    end
  end # create_base

  context "#create_body_container" do
    it 'calls #create_direct_container with hasBody' do
      expect(ldpw).to receive(:create_direct_container).with(RDF::Vocab::OA.hasBody)
      ldpw.create_body_container
    end
    it 'LDP store creates retrievable LDP DirectContainer with correct member relationships' do
      ldpw = Triannon::LdpWriter.new anno
      id = ldpw.create_base
      ldpw.create_body_container
      resp = conn.get do |req|
        req.url "#{id}/b"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{id}/b"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::LDP.DirectContainer]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::LDP.membershipResource, RDF::URI.new("#{Triannon.config[:ldp_url]}/#{id}")]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::LDP.hasMemberRelation, RDF::Vocab::OA.hasBody]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::LDP.contains, nil]).size).to eql 0
    end
  end

  context "#create_target_container" do
    it 'calls #create_direct_container with hasTarget' do
      expect(ldpw).to receive(:create_direct_container).with(RDF::Vocab::OA.hasTarget)
      ldpw.create_target_container
    end
    it 'LDP store creates retrievable LDP DirectContainer with correct member relationships' do
      ldpw = Triannon::LdpWriter.new anno
      id = ldpw.create_base
      ldpw.create_target_container
      resp = conn.get do |req|
        req.url "#{id}/t"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{id}/t"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::LDP.DirectContainer]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::LDP.membershipResource, RDF::URI.new("#{Triannon.config[:ldp_url]}/#{id}")]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::LDP.hasMemberRelation, RDF::Vocab::OA.hasTarget]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::LDP.contains, nil]).size).to eql 0
    end
  end

  context '#create_body_resources' do
    it "calls create_resources_in_container with hasBody predicate" do
      new_pid = ldpw.create_base
      ldpw.create_body_container
      expect(ldpw).to receive(:create_resources_in_container).with(RDF::Vocab::OA.hasBody)
      body_uuids = ldpw.create_body_resources
    end
    it 'creates resources in the body container' do
      ldpw = Triannon::LdpWriter.new anno
      id = ldpw.create_base
      ldpw.create_body_container
      body_uuids = ldpw.create_body_resources
      expect(body_uuids.size).to eql 1
      body_pid = "#{id}/b/#{body_uuids[0]}"
      resp = conn.get do |req|
        req.url body_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_body_obj_url = "#{Triannon.config[:ldp_url]}/#{body_pid}"
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF::Vocab::CNT.chars, "I love this!"]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF::Vocab::LDP.contains, RDF::URI.new(body_pid)]).size).to eql 0

      body_container_url = "#{Triannon.config[:ldp_url]}/#{id}/b"
      body_container_resp = conn.get do |req|
        req.url body_container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(body_container_resp.body)
      expect(g.query([RDF::URI.new(body_container_url), RDF::Vocab::LDP.contains, RDF::URI.new(full_body_obj_url)]).size).to eql 1
    end
  end # create_body_resources

  context '#create_target_resources' do
    it "calls create_resources_in_container with hasTarget predicate" do
      new_pid = ldpw.create_base
      ldpw.create_target_container
      expect(ldpw).to receive(:create_resources_in_container).with(RDF::Vocab::OA.hasTarget)
      body_uuids = ldpw.create_target_resources
    end
    it 'creates resources in the target container' do
      ldpw = Triannon::LdpWriter.new anno
      id = ldpw.create_base
      ldpw.create_target_container
      target_uuids = ldpw.create_target_resources
      expect(target_uuids.size).to eql 1
      target_pid = "#{id}/t/#{target_uuids[0]}"
      resp = conn.get do |req|
        req.url target_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_target_obj_url = "#{Triannon.config[:ldp_url]}/#{target_pid}"
      expect(g.query([RDF::URI.new(full_target_obj_url), RDF::Vocab::LDP.contains, RDF::URI.new(target_pid)]).size).to eql 0

      container_url = "#{Triannon.config[:ldp_url]}/#{id}/t"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, RDF::URI.new(full_target_obj_url)]).size).to eql 1
    end
  end # create_target_resources

  context '#delete_containers' do
    let(:base_uri) { Triannon.config[:ldp_url] }

    it 'deletes the resource from the LDP store when id is full url' do
      ldpw = Triannon::LdpWriter.new anno
      ldp_id = ldpw.create_base
      expect(ldp_id).not_to match base_uri
      ldpw.delete_containers ldp_id

      resp = conn.get do |req|
        req.url ldp_id
      end
      expect(resp.status).to eq 410
    end
    it 'works when id is just uuid' do
      ldpw = Triannon::LdpWriter.new anno
      ldp_id = ldpw.create_base

      ldpw.delete_containers ldp_id

      resp = conn.get do |req|
        req.url "#{base_uri}/#{ldp_id}"
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
      ldp_id = Triannon::LdpWriter.create_anno anno
      ldpw = Triannon::LdpWriter.new(nil)

      # delete the body resources
      l = Triannon::LdpLoader.new ldp_id
      l.load_anno_container
      ldpw.delete_containers l.ldp_annotation.body_uris

      # ensure the body container still exists
      resp = conn.get do |req|
        req.url "#{ldp_id}/b"
      end
      expect(resp.status).to eql 200
      expect(resp.body).to match /hasMemberRelation.*hasBody/
    end
    it 'deletes all child containers, recursively' do
      ldp_id = Triannon::LdpWriter.create_anno anno
      ldpw = Triannon::LdpWriter.new(nil)

      l = Triannon::LdpLoader.new ldp_id
      l.load_anno_container
      body_uris = l.ldp_annotation.body_uris
      expect(body_uris.size).to be > 0

      # delete body container
      ldpw.delete_containers "#{ldp_id}/b"

      # ensure no body objects still exist
      body_uris.each { |body_ldp_uri|
        # get the ids of the body resources
        resp = conn.get do |req|
          req.url body_ldp_uri
        end
        expect(resp.status).to eq 404
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

          writer = Triannon::LdpWriter.new anno
          allow(writer).to receive(:conn).and_return(my_conn)

          expect { writer.delete_containers([container_id]) }.to raise_error { |error|
            expect(error).to be_a Triannon::LDPStorageError
            expect(error.message).to eq "Unable to delete LDP container #{container_id}"
            expect(error.ldp_resp_status).to eq status_code
            expect(error.ldp_resp_body).to eq ldp_resp_body
          }
        }
      end
    end

  end # delete_containers

  context '#create_resource' do
    it "returns the last part of the url of the newly created resource, derived from Location header" do
      resp = double()
      allow(resp).to receive(:status).and_return(201)
      allow(resp).to receive(:body)
      allow(resp).to receive(:headers).and_return("Location" => "http://ldpstore.org/ldpcontainter/id")
      my_conn = double()
      allow(my_conn).to receive(:post).and_return(resp)
      my_svc = Triannon::LdpWriter.new anno
      allow(my_svc).to receive(:conn).and_return(my_conn)
      expect(my_svc.send(:create_resource, "ignore this fake turtle")).to eq "id"
    end
    context 'LDPStorageError' do
      it "raised with status code and body when LDP returns [404, 409, 412]" do
        rdf_as_string = "resource as string"
        container_id = "container_id"
        ldp_resp_body = "foo"
        [404, 409, 412].each { |status_code|
          ldp_resp = double()
          allow(ldp_resp).to receive(:body).and_return(ldp_resp_body)
          allow(ldp_resp).to receive(:status).and_return(status_code)
          my_conn = double()
          allow(my_conn).to receive(:post).and_return(ldp_resp)

          writer = Triannon::LdpWriter.new anno
          allow(writer).to receive(:conn).and_return(my_conn)

          expect { writer.send(:create_resource, rdf_as_string, container_id) }.to raise_error { |error|
            expect(error).to be_a Triannon::LDPStorageError
            expect(error.message).to eq "Unable to create LDP resource in container #{container_id}; RDF sent: #{rdf_as_string}"
            expect(error.ldp_resp_status).to eq status_code
            expect(error.ldp_resp_body).to eq ldp_resp_body
          }
        }
      end
    end
  end

  context '#create_direct_container' do
    it 'LDP store creates retrievable, empty LDP DirectContainer with expected id and LDP member relationships' do
      ldpw = Triannon::LdpWriter.new anno
      id = ldpw.create_base
      ldpw.send(:create_direct_container, RDF::Vocab::OA.hasTarget)
      cont_url = "#{id}/t"
      resp = conn.get do |req|
        req.url cont_url
        req.headers['Accept'] = 'text/turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_cont_url = "#{Triannon.config[:ldp_url]}/#{cont_url}"
      expect(g.query([RDF::URI.new(full_cont_url), RDF.type, RDF::Vocab::LDP.DirectContainer]).size).to eql 1
      expect(g.query([RDF::URI.new(full_cont_url), RDF::Vocab::LDP.membershipResource, RDF::URI.new("#{Triannon.config[:ldp_url]}/#{id}")]).size).to eql 1
      expect(g.query([RDF::URI.new(full_cont_url), RDF::Vocab::LDP.hasMemberRelation, RDF::Vocab::OA.hasTarget]).size).to eql 1
    end
    it 'has the correct ldp:memberRelation and id for hasTarget' do
      # see previous spec
    end
    it 'has the correct ldp:memberRelation and id for hasBody' do
      ldpw = Triannon::LdpWriter.new anno
      id = ldpw.create_base
      ldpw.send(:create_direct_container, RDF::Vocab::OA.hasBody)
      resp = conn.get do |req|
        req.url "#{id}/b"
        req.headers['Accept'] = 'text/turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_cont_url = "#{Triannon.config[:ldp_url]}/#{id}/b"
      expect(g.query([RDF::URI.new(full_cont_url), RDF::Vocab::LDP.hasMemberRelation, RDF::Vocab::OA.hasBody]).size).to eql 1
    end
    context 'LDPStorageError' do
      it "raised with status code and body when LDP returns [404, 409, 412]" do
        ldp_resp_body = "foo"
        [404, 409, 412].each { |status_code|
          ldp_resp = double()
          allow(ldp_resp).to receive(:body).and_return(ldp_resp_body)
          allow(ldp_resp).to receive(:status).and_return(status_code)
          my_conn = double()
          allow(my_conn).to receive(:post).and_return(ldp_resp)

          writer = Triannon::LdpWriter.new anno
          allow(writer).to receive(:conn).and_return(my_conn)

          expect { writer.send(:create_direct_container, RDF::Vocab::OA.hasTarget) }.to raise_error { |error|
            expect(error).to be_a Triannon::LDPStorageError
            expect(error.message).to match /^Unable to create Target LDP container for anno; RDF sent: /
            expect(error.ldp_resp_status).to eq status_code
            expect(error.ldp_resp_body).to eq ldp_resp_body
          }
        }
      end
    end
  end

  context '#create_resources_in_container' do
    it "target resources created in target container" do
      # see plain URI test
    end
    it "body resources created in body container" do
      # see ContentAsText tests
    end

    context 'ContentAsText' do
      it 'creates all appropriate statements for blank nodes, recursively' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "motivatedBy": "oa:commenting",
          "hasBody": {
            "@type": [
              "cnt:ContentAsText",
              "dctypes:Text"
            ],
            "chars": "I love this!",
            "language": "en"
          }
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        body_pid = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
        resp = conn.get do |req|
          req.url body_pid
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(body_pid), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
        expect(g.query([RDF::URI.new(body_pid), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
        expect(g.query([RDF::URI.new(body_pid), RDF::Vocab::CNT.chars, "I love this!"]).size).to eql 1
        expect(g.query([RDF::URI.new(body_pid), RDF::DC11.language, "en"]).size).to eql 1
      end
      it 'IIIF context flavor' do
        my_anno = Triannon::Annotation.new data: '{
          "@context":"http://iiif.io/api/presentation/2/context.json",
          "@type":"oa:Annotation",
          "motivation":"oa:commenting",
          "resource": {
            "@type":"cnt:ContentAsText",
            "chars":"I love this line!",
            "format":"text/plain"
          },
          "on":"http://www.example.org/iiif/book1/canvas/p1#xywh=400,100,1000,80"
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        body_pid = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
        resp = conn.get do |req|
          req.url body_pid
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        body_obj = RDF::URI.new(body_pid)
        expect(g.query([body_obj, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
        expect(g.query([body_obj, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 0
        expect(g.query([body_obj, RDF::Vocab::CNT.chars, "I love this line!"]).size).to eql 1
        expect(g.query([body_obj, RDF::DC11.format, "text/plain"]).size).to eql 1
      end
      it 'multiple resources' do
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
              "@type": [
                "cnt:ContentAsText",
                "dctypes:Text"
              ],
              "chars": "I hate this!"
            }
          ]
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        expect(body_uuids.size).to eql 2
        body_cont_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
        resp = conn.get do |req|
          req.url body_cont_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        contains_stmts = g.query([RDF::URI.new(body_cont_url), RDF::Vocab::LDP.contains, :body_url])
        expect(contains_stmts.size).to eql 2

        first_body_url = contains_stmts.first.object.to_s
        resp = conn.get do |req|
          req.url first_body_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
        expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
        expect(g.query([RDF::URI.new(first_body_url), RDF::Vocab::CNT.chars, "I love this!"]).size).to eql 1

        second_body_url = contains_stmts.to_a[1].object.to_s
        resp = conn.get do |req|
          req.url second_body_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(second_body_url), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
        expect(g.query([RDF::URI.new(second_body_url), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
        expect(g.query([RDF::URI.new(second_body_url), RDF::Vocab::CNT.chars, "I hate this!"]).size).to eql 1
      end
    end # ContentAsText

    context 'external URI' do
      it 'plain URI' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "motivatedBy": "oa:commenting",
          "hasBody": "http://dbpedia.org/resource/Otto_Ege"
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        expect(body_uuids.size).to eql 1
        body_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
        resp = conn.get do |req|
          req.url body_obj_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(body_obj_url), RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Otto_Ege")]).size).to eql 1
      end
      it 'URI has additional properties' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": {
            "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg#xywh=0,0,200,200",
            "@type": "dctypes:Image"
          }
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_target_container
        target_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasTarget)
        expect(target_uuids.size).to eql 1
        target_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
        resp = conn.get do |req|
          req.url target_obj_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        target_obj = RDF::URI.new(target_obj_url)
        expect(g.query([target_obj, RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg#xywh=0,0,200,200")]).size).to eql 1
        expect(g.query([target_obj, RDF.type, RDF::Vocab::DCMIType.Image]).size).to eql 1
      end
      it 'URI has semantic tag' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "motivatedBy": "oa:commenting",
          "hasBody": {
            "@id": "http://dbpedia.org/resource/Love",
            "@type": "oa:SemanticTag"
          }
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        expect(body_uuids.size).to eql 1
        body_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
        resp = conn.get do |req|
          req.url body_obj_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(body_obj_url), RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Love")]).size).to eql 1
        expect(g.query([RDF::URI.new(body_obj_url), RDF.type, RDF::Vocab::OA.SemanticTag]).size).to eql 1
      end
      it 'IIIF context has additional properties' do
        my_anno = Triannon::Annotation.new data: '{
          "@context":"http://iiif.io/api/presentation/2/context.json",
          "@type":"oa:Annotation",
          "motivation":"sc:painting",
          "resource": {
            "@id": "http://example.org/alto/p1.xml#xpointer(/alto/line[1])",
            "@type":"dctypes:Text",
            "format":"text/xml",
            "language":"en"
          },
          "on":"http://www.example.org/iiif/book1/canvas/p1#400,100,1000,100"
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        expect(body_uuids.size).to eql 1
        body_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
        resp = conn.get do |req|
          req.url body_obj_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        body_obj = RDF::URI.new(body_obj_url)
        expect(g.query([body_obj, RDF::Triannon.externalReference, RDF::URI.new("http://example.org/alto/p1.xml#xpointer(/alto/line[1])")]).size).to eql 1
        expect(g.query([body_obj, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
        expect(g.query([body_obj, RDF::DC11.format, "text/xml"]).size).to eql 1
        expect(g.query([body_obj, RDF::DC11.language, "en"]).size).to eql 1
      end
      it 'mult plain URIs' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": [
            "http://purl.stanford.edu/kq131cs7229",
            "http://purl.stanford.edu/oo000oo1234"
          ]
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_target_container
        target_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasTarget)
        expect(target_uuids.size).to eql 2

        container_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t"
        container_resp = conn.get do |req|
          req.url container_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(container_resp.body)
        expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, nil]).size).to eql 2

        first_target_url = "#{container_url}/#{target_uuids[0]}"
        resp = conn.get do |req|
          req.url first_target_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new
        g.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(first_target_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1

        second_target_url = "#{container_url}/#{target_uuids[1]}"
        resp = conn.get do |req|
          req.url second_target_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new
        g.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(second_target_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/oo000oo1234")]).size).to eql 1
      end
      it 'mult URIs with addl properties' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": [
            "http://purl.stanford.edu/kq131cs7229",
            {
              "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_thumb.jpg",
              "@type": "dctypes:Image"
            },
            {
              "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg",
              "@type": "dctypes:Image"
            }
          ]
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_target_container
        target_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasTarget)
        expect(target_uuids.size).to eql 3

        container_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t"
        container_resp = conn.get do |req|
          req.url container_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(container_resp.body)
        expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, nil]).size).to eql 3

        first_target_url = "#{container_url}/#{target_uuids[0]}"
        resp = conn.get do |req|
          req.url first_target_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new
        g.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(first_target_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1

        second_target_url = "#{container_url}/#{target_uuids[1]}"
        resp = conn.get do |req|
          req.url second_target_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new
        g.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(second_target_url), RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_thumb.jpg")]).size).to eql 1
        expect(g.query([RDF::URI.new(second_target_url), RDF.type, RDF::Vocab::DCMIType.Image]).size).to eql 1

        third_target_url = "#{container_url}/#{target_uuids[2]}"
        resp = conn.get do |req|
          req.url third_target_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new
        g.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(third_target_url), RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")]).size).to eql 1
        expect(g.query([RDF::URI.new(third_target_url), RDF.type, RDF::Vocab::DCMIType.Image]).size).to eql 1
      end
      it 'multiple URI resources with addl properties' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "motivatedBy": "oa:commenting",
          "hasBody": [
            {
              "@id": "http://dbpedia.org/resource/Love",
              "@type": "oa:SemanticTag"
            },
            {
              "@id": "http://www.example.org/comment.mp3",
              "@type": "dctypes:Sound"
            }
          ]
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        expect(body_uuids.size).to eql 2
        body_cont_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
        resp = conn.get do |req|
          req.url body_cont_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        contains_stmts = g.query([RDF::URI.new(body_cont_url), RDF::Vocab::LDP.contains, :body_url])
        expect(contains_stmts.size).to eql 2

        first_body_url = contains_stmts.first.object.to_s
        resp = conn.get do |req|
          req.url first_body_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(first_body_url), RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Love")]).size).to eql 1
        expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::Vocab::OA.SemanticTag]).size).to eql 1

        second_body_url = contains_stmts.to_a[1].object.to_s
        resp = conn.get do |req|
          req.url second_body_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(second_body_url), RDF::Triannon.externalReference, RDF::URI.new("http://www.example.org/comment.mp3")]).size).to eql 1
        expect(g.query([RDF::URI.new(second_body_url), RDF.type, RDF::Vocab::DCMIType.Sound]).size).to eql 1
      end
    end # external URI

    context 'SpecificResource' do
      it 'TextPositionSelector' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": {
            "@type": "oa:SpecificResource",
            "hasSource": "http://purl.stanford.edu/kq131cs7229.html",
            "hasSelector": {
              "@type": "oa:TextPositionSelector",
              "start": 0,
              "end": 66
            }
          }
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_target_container
        target_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasTarget)
        expect(target_uuids.size).to eql 1
        target_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
        resp = conn.get do |req|
          req.url target_obj_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        target_obj = RDF::URI.new(target_obj_url)
        expect(g.query([target_obj, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
        source_node_url = g.query([target_obj, RDF::Vocab::OA.hasSource, :source_node]).first.object.to_s
        # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
        expect(source_node_url).to match "#{target_obj_url}#source"  # this is a fcrepo4 implementation of hash URI node
        expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq131cs7229.html")]).size).to eql 1

        # the selector node object / ttl
        selector_node_url = g.query([target_obj, RDF::Vocab::OA.hasSelector, :selector_node]).first.object.to_s
        expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
        resp = conn.get do |req|
          req.url selector_node_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        selector_obj = RDF::URI.new(selector_node_url)
        expect(g.query([selector_obj, RDF.type, RDF::Vocab::OA.TextPositionSelector]).size).to eql 1
        expect(g.query([selector_obj, RDF::Vocab::OA.start, RDF::Literal.new(0)]).size).to eql 1
        expect(g.query([selector_obj, RDF::Vocab::OA.end, RDF::Literal.new(66)]).size).to eql 1
      end
      it "TextQuoteSelector" do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": {
            "@type": "oa:SpecificResource",
            "hasSource": "http://purl.stanford.edu/kq131cs7229.html",
            "hasSelector": {
              "@type": "oa:TextQuoteSelector",
              "suffix": " and The Canonical Epistles,",
              "exact": "third and fourth Gospels",
              "prefix": "manuscript which comprised the "
            }
          }
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_target_container
        target_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasTarget)
        expect(target_uuids.size).to eql 1
        target_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
        resp = conn.get do |req|
          req.url target_obj_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        target_obj = RDF::URI.new(target_obj_url)
        expect(g.query([target_obj, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
        source_node_url = g.query([target_obj, RDF::Vocab::OA.hasSource, :source_node]).first.object.to_s
        # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
        expect(source_node_url).to match "#{target_obj_url}#source"  # this is a fcrepo4 implementation of hash URI node
        expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq131cs7229.html")]).size).to eql 1

        # the selector node object / ttl
        selector_node_url = g.query([target_obj, RDF::Vocab::OA.hasSelector, :selector_node]).first.object.to_s
        expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
        resp = conn.get do |req|
          req.url selector_node_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        selector_obj = RDF::URI.new(selector_node_url)
        expect(g.query([selector_obj, RDF.type, RDF::Vocab::OA.TextQuoteSelector]).size).to eql 1
        expect(g.query([selector_obj, RDF::Vocab::OA.suffix, RDF::Literal.new(" and The Canonical Epistles,")]).size).to eql 1
        expect(g.query([selector_obj, RDF::Vocab::OA.prefix, RDF::Literal.new("manuscript which comprised the ")]).size).to eql 1
        expect(g.query([selector_obj, RDF::Vocab::OA.exact, RDF::Literal.new("third and fourth Gospels")]).size).to eql 1
      end
      it 'FragmentSelector with Source having addl metadata' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": {
            "@type": "oa:SpecificResource",
            "hasSource": {
              "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg",
              "@type": "dctypes:Image"
            },
            "hasSelector": {
              "@type": "oa:FragmentSelector",
              "value": "xywh=0,0,200,200",
              "conformsTo": "http://www.w3.org/TR/media-frags/"
            }
          }
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_target_container
        target_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasTarget)
        expect(target_uuids.size).to eql 1
        target_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
        resp = conn.get do |req|
          req.url target_obj_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        target_obj = RDF::URI.new(target_obj_url)
        expect(g.query([target_obj, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
        source_node_url = g.query([target_obj, RDF::Vocab::OA.hasSource, :source_node]).first.object.to_s
        # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
        expect(source_node_url).to match "#{target_obj_url}#source"
        expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")]).size).to eql 1
        expect(g.query([RDF::URI.new(source_node_url), RDF.type, RDF::Vocab::DCMIType.Image]).size).to eql 1

        # the selector node object / ttl
        selector_node_url = g.query([target_obj, RDF::Vocab::OA.hasSelector, :selector_node]).first.object.to_s
        expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
        resp = conn.get do |req|
          req.url selector_node_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        selector_obj = RDF::URI.new(selector_node_url)
        expect(g.query([selector_obj, RDF.type, RDF::Vocab::OA.FragmentSelector]).size).to eql 1
        expect(g.query([selector_obj, RDF.value, RDF::Literal.new("xywh=0,0,200,200")]).size).to eql 1
        expect(g.query([selector_obj, RDF::DC.conformsTo, RDF::URI.new("http://www.w3.org/TR/media-frags/")]).size).to eql 1
      end
#      it "DataPositionSelector" do
#        skip 'DataPositionSelector not yet implemented'
#      end
#      it "SvgSelector" do
#        skip 'SvgSelector not yet implemented'
#      end
      it 'multiple SpecificResources' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "hasTarget": [
            "http://purl.stanford.edu/kq131cs7229",
            {
              "@type": "oa:SpecificResource",
              "hasSource": "http://purl.stanford.edu/kq666cs6666.html",
              "hasSelector": {
                "@type": "oa:TextPositionSelector",
                "start": 0,
                "end": 66
              }
            },
            {
              "@type": "oa:SpecificResource",
              "hasSource": {
                "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg",
                "@type": "dctypes:Image"
              },
              "hasSelector": {
                "@type": "oa:FragmentSelector",
                "value": "xywh=0,0,200,200",
                "conformsTo": "http://www.w3.org/TR/media-frags/"
              }
            }
          ]
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_target_container
        target_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasTarget)
        expect(target_uuids.size).to eql 3

        container_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t"
        container_resp = conn.get do |req|
          req.url container_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(container_resp.body)
        expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, nil]).size).to eql 3

        first_target_url = "#{container_url}/#{target_uuids[0]}"
        resp = conn.get do |req|
          req.url first_target_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(first_target_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1


        second_target_url = "#{container_url}/#{target_uuids[1]}"
        resp = conn.get do |req|
          req.url second_target_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        target_obj = RDF::URI.new(second_target_url)
        expect(g.query([target_obj, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
        source_node_url = g.query([target_obj, RDF::Vocab::OA.hasSource, :source_node]).first.object.to_s
        # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
        expect(source_node_url).to match "#{second_target_url}#source"
        expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq666cs6666.html")]).size).to eql 1

        # the selector node object / ttl
        selector_node_url = g.query([target_obj, RDF::Vocab::OA.hasSelector, :selector_node]).first.object.to_s
        expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
        resp = conn.get do |req|
          req.url selector_node_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        selector_obj = RDF::URI.new(selector_node_url)
        expect(g.query([selector_obj, RDF.type, RDF::Vocab::OA.TextPositionSelector]).size).to eql 1
        expect(g.query([selector_obj, RDF::Vocab::OA.start, RDF::Literal.new(0)]).size).to eql 1
        expect(g.query([selector_obj, RDF::Vocab::OA.end, RDF::Literal.new(66)]).size).to eql 1


        third_target_url = "#{container_url}/#{target_uuids[2]}"
        resp = conn.get do |req|
          req.url third_target_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        target_obj = RDF::URI.new(third_target_url)
        expect(g.query([target_obj, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
        source_node_url = g.query([target_obj, RDF::Vocab::OA.hasSource, :source_node]).first.object.to_s
        # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
        expect(source_node_url).to match "#{third_target_url}#source"
        expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")]).size).to eql 1
        expect(g.query([RDF::URI.new(source_node_url), RDF.type, RDF::Vocab::DCMIType.Image]).size).to eql 1

        # the selector node object / ttl
        selector_node_url = g.query([target_obj, RDF::Vocab::OA.hasSelector, :selector_node]).first.object.to_s
        expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
        resp = conn.get do |req|
          req.url selector_node_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        selector_obj = RDF::URI.new(selector_node_url)
        expect(g.query([selector_obj, RDF.type, RDF::Vocab::OA.FragmentSelector]).size).to eql 1
        expect(g.query([selector_obj, RDF.value, RDF::Literal.new("xywh=0,0,200,200")]).size).to eql 1
        expect(g.query([selector_obj, RDF::DC.conformsTo, RDF::URI.new("http://www.w3.org/TR/media-frags/")]).size).to eql 1
      end
    end # SpecificResource

    context 'Choice' do
      it 'contains all appropriate statements for blank nodes, recursively' do
        my_anno = Triannon::Annotation.new data: '{
          "@context": "http://www.w3.org/ns/oa-context-20130208.json",
          "@type": "oa:Annotation",
          "motivatedBy": "oa:commenting",
          "hasBody": {
            "@type": "oa:Choice",
            "default": {
              "@type": [
                "cnt:ContentAsText",
                "dctypes:Text"
              ],
              "chars": "I love this Englishly!",
              "language": "en"
            },
            "item": [
              {
                "@type": [
                  "cnt:ContentAsText",
                  "dctypes:Text"
                ],
                "chars": "Je l\'aime en Francais!",
                "language": "fr"
              }
            ]
          }
        }'
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        expect(body_uuids.size).to eql 1
        body_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
        body_resp = conn.get do |req|
          req.url body_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(body_resp.body)
        expect(g.query([RDF::URI.new(body_url), RDF.type, RDF::Vocab::OA.Choice]).size).to eql 1
        expect(g.query([RDF::URI.new(body_url), RDF::Vocab::OA.default, nil]).size).to eql 1
        expect(g.query([RDF::URI.new(body_url), RDF::Vocab::OA.item, nil]).size).to eql 1

        default_node_pid = g.query([RDF::URI.new(body_url), RDF::Vocab::OA.default, :default_blank_node]).first.object.to_s
        item_node_pid = g.query([RDF::URI.new(body_url), RDF::Vocab::OA.item, :item_blank_node]).first.object.to_s

        # the default blank node object / ttl
        expect(default_node_pid).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
        resp = conn.get do |req|
          req.url default_node_pid
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(default_node_pid), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
        expect(g.query([RDF::URI.new(default_node_pid), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
        expect(g.query([RDF::URI.new(default_node_pid), RDF::Vocab::CNT.chars, "I love this Englishly!"]).size).to eql 1
        expect(g.query([RDF::URI.new(default_node_pid), RDF::DC11.language, "en"]).size).to eql 1

        # the item blank node object / ttl
        expect(item_node_pid).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
        resp = conn.get do |req|
          req.url item_node_pid
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(item_node_pid), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
        expect(g.query([RDF::URI.new(item_node_pid), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
        expect(g.query([RDF::URI.new(item_node_pid), RDF::Vocab::CNT.chars, "Je l'aime en Francais!"]).size).to eql 1
        expect(g.query([RDF::URI.new(item_node_pid), RDF::DC11.language, "fr"]).size).to eql 1
      end
      it "three images" do
        body_url = "http://dbpedia.org/resource/Otto_Ege"
        default_url = "http://images.com/small"
        item1_url = "http://images.com/large"
        item2_url = "http://images.com/huge"
        my_anno = Triannon::Annotation.new data: "
        @prefix openannotation: <http://www.w3.org/ns/oa#> .
        @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

         [
            a openannotation:Annotation;

            openannotation:hasBody <#{body_url}>;
            openannotation:hasTarget [
              a openannotation:Choice;
              openannotation:default <#{default_url}>;
              openannotation:item <#{item1_url}>;
              openannotation:item <#{item2_url}>
            ];
            openannotation:motivatedBy openannotation:commenting
         ] .

         <#{default_url}> a dcmitype:Image .

         <#{item1_url}> a dcmitype:Image .

         <#{item2_url}> a dcmitype:Image ."
         my_ldpw = Triannon::LdpWriter.new my_anno
         new_pid = my_ldpw.create_base
         my_ldpw.create_target_container
         target_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasTarget)
         expect(target_uuids.size).to eql 1
         target_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
         target_resp = conn.get do |req|
           req.url target_url
           req.headers['Accept'] = 'application/x-turtle'
         end
         g = RDF::Graph.new.from_ttl(target_resp.body)
         g = OA::Graph.remove_fedora_triples(g)
         target_node_obj = RDF::URI.new(target_url)
         expect(g.query([target_node_obj, RDF.type, RDF::Vocab::OA.Choice]).size).to eql 1
         default_pid_solns = g.query [target_node_obj, RDF::Vocab::OA.default, nil]
         expect(default_pid_solns.count).to eql 1
         default_node_pid = default_pid_solns.first.object.to_s
         expect(default_node_pid).to match "#{target_url}#default" # this is a fcrepo4 implementation of hash URI node
         item_pid_solns = g.query([target_node_obj, RDF::Vocab::OA.item, nil])
         expect(item_pid_solns.count).to eql 2
         item1_pid = item_pid_solns.first.object.to_s
         expect(item1_pid).to match "#{target_url}#item" # this is a fcrepo4 implementation of hash URI node
         item2_pid = item_pid_solns.to_a.last.object.to_s
         expect(item2_pid).to match "#{target_url}#item" # this is a fcrepo4 implementation of hash URI node

         # the default blank node object / ttl
         #  hashURI is in the same response due to fcrepo4 implementation
         default_node_obj = RDF::URI.new(default_node_pid)
         default_subj_solns = g.query([default_node_obj, nil, nil])
         expect(default_subj_solns.count).to eql 2
         expect(default_subj_solns).to include [default_node_obj, RDF.type, RDF::Vocab::DCMIType.Image]
         expect(default_subj_solns).to include [default_node_obj, RDF::Triannon.externalReference, RDF::URI.new(default_url)]

         # the first item blank node object / ttl
         item1_node_obj = RDF::URI.new(item1_pid)
         item1_subj_solns = g.query([item1_node_obj, nil, nil])
         expect(item1_subj_solns.count).to eql 2
         expect(item1_subj_solns).to include [item1_node_obj, RDF.type, RDF::Vocab::DCMIType.Image]
         item_url = g.query([item1_node_obj, RDF::Triannon.externalReference, nil]).first.object.to_s
         expect([item1_url, item2_url]).to include item_url

         # the second item blank node object / ttl
         item2_node_obj = RDF::URI.new(item2_pid)
         item2_subj_solns = g.query([item2_node_obj, nil, nil])
         expect(item2_subj_solns.count).to eql 2
         expect(item2_subj_solns).to include [item2_node_obj, RDF.type, RDF::Vocab::DCMIType.Image]
         item_url = g.query([item2_node_obj, RDF::Triannon.externalReference, nil]).first.object.to_s
         expect([item1_url, item2_url]).to include item_url
      end
    end # Choice

    context 'multiple resources of different types' do
      it 'multiple resources (one URI)' do
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
        my_ldpw = Triannon::LdpWriter.new my_anno
        new_pid = my_ldpw.create_base
        my_ldpw.create_body_container
        body_uuids = my_ldpw.send(:create_resources_in_container, RDF::Vocab::OA.hasBody)
        expect(body_uuids.size).to eql 2
        body_cont_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
        resp = conn.get do |req|
          req.url body_cont_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        contains_stmts = g.query([RDF::URI.new(body_cont_url), RDF::Vocab::LDP.contains, :body_url])
        expect(contains_stmts.size).to eql 2

        first_body_url = contains_stmts.first.object.to_s
        resp = conn.get do |req|
          req.url first_body_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
        expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
        expect(g.query([RDF::URI.new(first_body_url), RDF::Vocab::CNT.chars, "I love this!"]).size).to eql 1

        second_body_url = contains_stmts.to_a[1].object.to_s
        resp = conn.get do |req|
          req.url second_body_url
          req.headers['Accept'] = 'application/x-turtle'
        end
        g = RDF::Graph.new.from_ttl(resp.body)
        expect(g.query([RDF::URI.new(second_body_url), RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Love")]).size).to eql 1
        expect(g.query([RDF::URI.new(second_body_url), RDF.type, RDF::Vocab::OA.SemanticTag]).size).to eql 1
      end
    end
  end # create_resources_in_container

  describe '#conn' do
    it "returns a Faraday::Connection" do
      conn = ldpw.send(:conn)
      expect(conn).to be_a Faraday::Connection
    end
    it "sets Prefer header to omit server managed triples" do
      conn = ldpw.send(:conn)
      expect(conn.headers).to include("Prefer" => 'return=respresentation; omit="http://fedora.info/definitions/v4/repository#ServerManaged"')
    end
  end
end
