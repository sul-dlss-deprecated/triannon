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
  let(:triannon_anno_container) {"#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"}
  let(:conn) { Faraday.new(url: triannon_anno_container) }

  context "#create_base" do
    it 'LDP store creates Basic Container for the annotation and returns id' do
      new_pid = ldpw.create_base
      resp = conn.get do |req|
        req.url new_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(resp.body)
      full_url = "#{triannon_anno_container}/#{new_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::LDP.BasicContainer]).size).to eql 1
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
      full_url = "#{triannon_anno_container}/#{base_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.motivatedBy, RDF::Vocab::IIIF.painting]).size).to eql 1
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
      full_url = "#{triannon_anno_container}/#{new_pid}"
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
      full_url = "#{triannon_anno_container}/#{new_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
      xsd_dt_literal_opts = {datatype: RDF::XSD.dateTimeStamp}
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.annotatedAt, RDF::Literal.new("2014-09-03T17:16:13Z", xsd_dt_literal_opts)]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.annotatedBy, nil]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::OA.serializedAt, RDF::Literal.new("2014-09-03T17:16:13Z", xsd_dt_literal_opts)]).size).to eql 1
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
      full_url = "#{triannon_anno_container}/#{id}/b"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::LDP.DirectContainer]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::LDP.membershipResource, RDF::URI.new("#{triannon_anno_container}/#{id}")]).size).to eql 1
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
      full_url = "#{triannon_anno_container}/#{id}/t"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::Vocab::LDP.DirectContainer]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::Vocab::LDP.membershipResource, RDF::URI.new("#{triannon_anno_container}/#{id}")]).size).to eql 1
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
      full_body_obj_url = "#{triannon_anno_container}/#{body_pid}"
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF::Vocab::CNT.chars, "I love this!"]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF::Vocab::LDP.contains, RDF::URI.new(body_pid)]).size).to eql 0

      body_container_url = "#{triannon_anno_container}/#{id}/b"
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
      full_target_obj_url = "#{triannon_anno_container}/#{target_pid}"
      expect(g.query([RDF::URI.new(full_target_obj_url), RDF::Vocab::LDP.contains, RDF::URI.new(target_pid)]).size).to eql 0

      container_url = "#{triannon_anno_container}/#{id}/t"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::Vocab::LDP.contains, RDF::URI.new(full_target_obj_url)]).size).to eql 1
    end
  end # create_target_resources

  context '#delete_containers' do
    let(:base_uri) { "#{triannon_anno_container}" }

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

      l = Triannon::LdpLoader.new ldp_id
      l.load_anno_container
      body_uris = l.ldp_annotation.body_uris
      expect(body_uris.size).to be > 0

      # delete body container
      ldpw = Triannon::LdpWriter.new(nil)
      ldpw.delete_containers "#{ldp_id}/b"

      # ensure no body objects still exist
      body_uris.each { |body_ldp_uri|
        # get the ids of the body resources
        resp = conn.get do |req|
          req.url body_ldp_uri
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

end
