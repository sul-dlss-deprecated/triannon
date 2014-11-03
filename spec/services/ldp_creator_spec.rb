require 'spec_helper'

vcr_options = {:re_record_interval => 45.days}  # TODO will make shorter once we have jetty running fedora4
describe Triannon::LdpCreator, :vcr => vcr_options do

  let(:anno) { Triannon::Annotation.new data: '
    <> a <http://www.w3.org/ns/oa#Annotation>;
       <http://www.w3.org/ns/oa#hasBody> [
         a <http://www.w3.org/2011/content#ContentAsText>,
           <http://purl.org/dc/dcmitype/Text>;
         <http://www.w3.org/2011/content#chars> "I love this!"
       ];
       <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>;
       <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#commenting> .' }
  let(:svc) { Triannon::LdpCreator.new anno }
  let(:conn) { Faraday.new(:url => Triannon.config[:ldp_url]) }

  describe "#create_base" do
    it 'LDP store creates retrievable object representing the annotation and returns id' do
      new_pid = svc.create_base
      resp = conn.get do |req|
        req.url "#{new_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{new_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      resp = conn.get do |req|
        req.url "#{new_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{new_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.moderating]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.tagging]).size).to eql 1
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      resp = conn.get do |req|
        req.url "#{new_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{new_pid}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::OpenAnnotation.annotatedAt, "2014-09-03T17:16:13Z"]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::OpenAnnotation.annotatedBy, nil]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::OpenAnnotation.serializedAt, "2014-09-03T17:16:13Z"]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::OpenAnnotation.serializedBy, nil]).size).to eql 1
    end
  end # create_base

  describe "#create_body_container" do
    it 'calls #create_direct_container with hasBody' do
      expect(svc).to receive(:create_direct_container).with(RDF::OpenAnnotation.hasBody)
      svc.create_body_container
    end
    it 'LDP store creates retrievable LDP DirectContainer with correct member relationships' do
      new_pid = svc.create_base
      svc.create_body_container
      resp = conn.get do |req|
        req.url " #{new_pid}/b"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::LDP.DirectContainer]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::LDP.membershipResource, RDF::URI.new("#{Triannon.config[:ldp_url]}/#{new_pid}")]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::LDP.hasMemberRelation, RDF::OpenAnnotation.hasBody]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::LDP.contains, nil]).size).to eql 0
    end
  end

  describe "#create_target_container" do
    it 'calls #create_direct_container with hasBody' do
      expect(svc).to receive(:create_direct_container).with(RDF::OpenAnnotation.hasTarget)
      svc.create_target_container
    end
    it 'LDP store creates retrievable LDP DirectContainer with correct member relationships' do
      new_pid = svc.create_base
      svc.create_target_container
      resp = conn.get do |req|
        req.url " #{new_pid}/t"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::LDP.DirectContainer]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::LDP.membershipResource, RDF::URI.new("#{Triannon.config[:ldp_url]}/#{new_pid}")]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::LDP.hasMemberRelation, RDF::OpenAnnotation.hasTarget]).size).to eql 1
      expect(g.query([RDF::URI.new(full_url), RDF::LDP.contains, nil]).size).to eql 0
    end
  end

  describe '.create class method' do
    it 'should call create_base' do
      expect_any_instance_of(Triannon::LdpCreator).to receive(:create_base)
      Triannon::LdpCreator.create anno
    end
    it 'should return the pid of the annotation container in fedora' do
      id = Triannon::LdpCreator.create anno
      expect(id).to be_a String
      expect(id.size).to be > 10
      resp = conn.get do |req|
        req.url "#{id}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_url = "#{Triannon.config[:ldp_url]}/#{id}"
      expect(g.query([RDF::URI.new(full_url), RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    end
    it 'should not create a body container if there are no bodies' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "hasTarget": "http://purl.stanford.edu/kq131cs7229"
      }'
      expect_any_instance_of(Triannon::LdpCreator).not_to receive(:create_body_container)
      Triannon::LdpCreator.create my_anno
    end
    it 'should create a fedora resource for bodies ldp container at (id)/b' do
      pid = Triannon::LdpCreator.create anno
      container_url = "#{Triannon.config[:ldp_url]}/#{pid}/b"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::LDP.contains, nil]).size).to eql 1
    end
    it 'should call create_body_container and create_body_resources if there are bodies' do
      expect_any_instance_of(Triannon::LdpCreator).to receive(:create_body_container).and_call_original
      expect_any_instance_of(Triannon::LdpCreator).to receive(:create_body_resources)
      Triannon::LdpCreator.create anno
    end
    it 'should create a single body container with multiple resources if there are multiple bodies' do
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
      id = Triannon::LdpCreator.create my_anno
      container_url = "#{Triannon.config[:ldp_url]}/#{id}/b"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::LDP.contains, nil]).size).to eql 2
    end
    it 'should call create_target_container and create_target_resource' do
      expect_any_instance_of(Triannon::LdpCreator).to receive(:create_target_container).and_call_original
      expect_any_instance_of(Triannon::LdpCreator).to receive(:create_target_resources)
      Triannon::LdpCreator.create anno
    end
    it 'should create a fedora resource for targets ldp container at (id)/t' do
      pid = Triannon::LdpCreator.create anno
      container_url = "#{Triannon.config[:ldp_url]}/#{pid}/t"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::LDP.contains, nil]).size).to eql 1
    end
    it 'should create a single target container with multiple resources if there are multiple targets' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "hasTarget": [
          "http://purl.stanford.edu/kq131cs7229",
          "http://purl.stanford.edu/oo000oo1234"
        ]
      }'
      id = Triannon::LdpCreator.create my_anno
      container_url = "#{Triannon.config[:ldp_url]}/#{id}/t"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::LDP.contains, nil]).size).to eql 2
    end
  end # create class method

  describe '#create_body_resources' do
    it 'creates resources in the body container' do
      new_pid = svc.create_base
      svc.create_body_container
      body_uuids = svc.create_body_resources
      expect(body_uuids.size).to eql 1
      body_pid = "#{new_pid}/b/#{body_uuids[0]}"
      resp = conn.get do |req|
        req.url body_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_body_obj_url = "#{Triannon.config[:ldp_url]}/#{body_pid}"
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF::Content.chars, "I love this!"]).size).to eql 1
      expect(g.query([RDF::URI.new(full_body_obj_url), RDF::LDP.contains, RDF::URI.new(body_pid)]).size).to eql 0
      
      body_container_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
      body_container_resp = conn.get do |req|
        req.url body_container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(body_container_resp.body)
      expect(g.query([RDF::URI.new(body_container_url), RDF::LDP.contains, RDF::URI.new(full_body_obj_url)]).size).to eql 1
    end
    it 'creates all appropriate statements for has_body blank nodes, recursively' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_body_container
      body_uuids = my_svc.create_body_resources
      body_pid = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
      resp = conn.get do |req|
        req.url body_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(body_pid), RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(body_pid), RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(body_pid), RDF::Content.chars, "I love this!"]).size).to eql 1
      expect(g.query([RDF::URI.new(body_pid), RDF::DC11.language, "en"]).size).to eql 1
    end
    it 'contains all appropriate statements for has_body blank nodes, recursively, oa:Choice' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_body_container
      body_uuids = my_svc.create_body_resources
      expect(body_uuids.size).to eql 1
      body_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
      body_resp = conn.get do |req|
        req.url body_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(body_resp.body)
      expect(g.query([RDF::URI.new(body_url), RDF.type, RDF::OpenAnnotation.Choice]).size).to eql 1
      expect(g.query([RDF::URI.new(body_url), RDF::OpenAnnotation.default, nil]).size).to eql 1
      expect(g.query([RDF::URI.new(body_url), RDF::OpenAnnotation.item, nil]).size).to eql 1

      default_node_pid = g.query([RDF::URI.new(body_url), RDF::OpenAnnotation.default, :default_blank_node]).first.object.to_s
      item_node_pid = g.query([RDF::URI.new(body_url), RDF::OpenAnnotation.item, :item_blank_node]).first.object.to_s

      # the default blank node object / ttl
      expect(default_node_pid).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url default_node_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(default_node_pid), RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(default_node_pid), RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(default_node_pid), RDF::Content.chars, "I love this Englishly!"]).size).to eql 1
      expect(g.query([RDF::URI.new(default_node_pid), RDF::DC11.language, "en"]).size).to eql 1

      # the item blank node object / ttl
      expect(item_node_pid).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url item_node_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(item_node_pid), RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(item_node_pid), RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(item_node_pid), RDF::Content.chars, "Je l'aime en Francais!"]).size).to eql 1
      expect(g.query([RDF::URI.new(item_node_pid), RDF::DC11.language, "fr"]).size).to eql 1
    end
    it 'body is a simple URI' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "motivatedBy": "oa:commenting", 
        "hasBody": "http://dbpedia.org/resource/Otto_Ege"
      }'
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_body_container
      body_uuids = my_svc.create_body_resources
      expect(body_uuids.size).to eql 1
      body_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
      resp = conn.get do |req|
        req.url body_obj_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(body_obj_url), RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Otto_Ege")]).size).to eql 1
    end
    it 'body URI has semantic tag' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "motivatedBy": "oa:commenting", 
        "hasBody": {
          "@id": "http://dbpedia.org/resource/Love", 
          "@type": "oa:SemanticTag"
        }
      }'
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_body_container
      body_uuids = my_svc.create_body_resources 
      expect(body_uuids.size).to eql 1
      body_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
      resp = conn.get do |req|
        req.url body_obj_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(body_obj_url), RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Love")]).size).to eql 1
      expect(g.query([RDF::URI.new(body_obj_url), RDF.type, RDF::OpenAnnotation.SemanticTag]).size).to eql 1
    end
    it 'body URI has additional properties' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "motivatedBy": "oa:commenting", 
        "hasBody": {
          "@id": "http://www.example.org/comment.pdf", 
          "@type": "dctypes:Text"
        }
      }'
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_body_container
      body_uuids = my_svc.create_body_resources 
      expect(body_uuids.size).to eql 1
      body_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuids[0]}"
      resp = conn.get do |req|
        req.url body_obj_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(body_obj_url), RDF::Triannon.externalReference, RDF::URI.new("http://www.example.org/comment.pdf")]).size).to eql 1
      expect(g.query([RDF::URI.new(body_obj_url), RDF.type, RDF::DCMIType.Text]).size).to eql 1
    end
    it 'multiple bodies (no URIs)' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_body_container
      body_uuids = my_svc.create_body_resources
      expect(body_uuids.size).to eql 2
      body_cont_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
      resp = conn.get do |req|
        req.url body_cont_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      contains_stmts = g.query([RDF::URI.new(body_cont_url), RDF::LDP.contains, :body_url])
      expect(contains_stmts.size).to eql 2

      first_body_url = contains_stmts.first.object.to_s
      resp = conn.get do |req|
        req.url first_body_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(first_body_url), RDF::Content.chars, "I love this!"]).size).to eql 1

      second_body_url = contains_stmts.to_a[1].object.to_s
      resp = conn.get do |req|
        req.url second_body_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(second_body_url), RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(second_body_url), RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(second_body_url), RDF::Content.chars, "I hate this!"]).size).to eql 1
    end
    it 'multiple bodies (one URI)' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_body_container
      body_uuids = my_svc.create_body_resources
      expect(body_uuids.size).to eql 2
      body_cont_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
      resp = conn.get do |req|
        req.url body_cont_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      contains_stmts = g.query([RDF::URI.new(body_cont_url), RDF::LDP.contains, :body_url])
      expect(contains_stmts.size).to eql 2

      first_body_url = contains_stmts.first.object.to_s
      resp = conn.get do |req|
        req.url first_body_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(g.query([RDF::URI.new(first_body_url), RDF::Content.chars, "I love this!"]).size).to eql 1

      second_body_url = contains_stmts.to_a[1].object.to_s
      resp = conn.get do |req|
        req.url second_body_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(second_body_url), RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Love")]).size).to eql 1
      expect(g.query([RDF::URI.new(second_body_url), RDF.type, RDF::OpenAnnotation.SemanticTag]).size).to eql 1
    end
    it 'multiple URI bodies with addl properties' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_body_container
      body_uuids = my_svc.create_body_resources
      expect(body_uuids.size).to eql 2
      body_cont_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
      resp = conn.get do |req|
        req.url body_cont_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      contains_stmts = g.query([RDF::URI.new(body_cont_url), RDF::LDP.contains, :body_url])
      expect(contains_stmts.size).to eql 2

      first_body_url = contains_stmts.first.object.to_s
      resp = conn.get do |req|
        req.url first_body_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(first_body_url), RDF::Triannon.externalReference, RDF::URI.new("http://dbpedia.org/resource/Love")]).size).to eql 1
      expect(g.query([RDF::URI.new(first_body_url), RDF.type, RDF::OpenAnnotation.SemanticTag]).size).to eql 1

      second_body_url = contains_stmts.to_a[1].object.to_s
      resp = conn.get do |req|
        req.url second_body_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(second_body_url), RDF::Triannon.externalReference, RDF::URI.new("http://www.example.org/comment.mp3")]).size).to eql 1
      expect(g.query([RDF::URI.new(second_body_url), RDF.type, RDF::DCMIType.Sound]).size).to eql 1
    end
  end # create_body_resources

  describe '#create_target_resources' do
    it 'creates resources in the target container' do
      new_pid = svc.create_base
      svc.create_target_container
      target_uuids = svc.create_target_resources
      expect(target_uuids.size).to eql 1
      target_pid = "#{new_pid}/t/#{target_uuids[0]}"
      resp = conn.get do |req|
        req.url target_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_target_obj_url = "#{Triannon.config[:ldp_url]}/#{target_pid}"
      expect(g.query([RDF::URI.new(full_target_obj_url), RDF::LDP.contains, RDF::URI.new(target_pid)]).size).to eql 0

      container_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::LDP.contains, RDF::URI.new(full_target_obj_url)]).size).to eql 1
    end
    it 'target is simple URI' do
      new_pid = svc.create_base
      svc.create_target_container
      target_uuids = svc.create_target_resources
      expect(target_uuids.size).to eql 1
      target_pid = "#{new_pid}/t/#{target_uuids[0]}"
      resp = conn.get do |req|
        req.url target_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_target_obj_url = "#{Triannon.config[:ldp_url]}/#{target_pid}"
      expect(g.query([RDF::URI.new(full_target_obj_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1
    end
    it 'target URI has additional properties' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "hasTarget": {
          "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg#xywh=0,0,200,200",
          "@type": "dctypes:Image"
        }
      }'
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_target_container
      target_uuids = my_svc.create_target_resources 
      expect(target_uuids.size).to eql 1
      target_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
      resp = conn.get do |req|
        req.url target_obj_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      target_obj = RDF::URI.new(target_obj_url)
      expect(g.query([target_obj, RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg#xywh=0,0,200,200")]).size).to eql 1
      expect(g.query([target_obj, RDF.type, RDF::DCMIType.Image]).size).to eql 1
    end
    it 'target is blank node' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_target_container
      target_uuids = my_svc.create_target_resources 
      expect(target_uuids.size).to eql 1
      target_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
      resp = conn.get do |req|
        req.url target_obj_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      target_obj = RDF::URI.new(target_obj_url)
      expect(g.query([target_obj, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
      source_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSource, :source_node]).first.object.to_s
      # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
      expect(source_node_url).to match "#{target_obj_url}#source"  # this is a fcrepo4 implementation of hash URI node
      expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq131cs7229.html")]).size).to eql 1
      
      # the selector node object / ttl
      selector_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSelector, :selector_node]).first.object.to_s
      expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url selector_node_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      selector_obj = RDF::URI.new(selector_node_url)
      expect(g.query([selector_obj, RDF.type, RDF::OpenAnnotation.TextPositionSelector]).size).to eql 1
      expect(g.query([selector_obj, RDF::OpenAnnotation.start, RDF::Literal.new(0)]).size).to eql 1
      expect(g.query([selector_obj, RDF::OpenAnnotation.end, RDF::Literal.new(66)]).size).to eql 1
    end
    it 'target has multiple blank at second level' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_target_container
      target_uuids = my_svc.create_target_resources 
      expect(target_uuids.size).to eql 1
      target_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
      resp = conn.get do |req|
        req.url target_obj_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      target_obj = RDF::URI.new(target_obj_url)
      expect(g.query([target_obj, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
      source_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSource, :source_node]).first.object.to_s
      # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
      expect(source_node_url).to match "#{target_obj_url}#source"
      expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")]).size).to eql 1
      expect(g.query([RDF::URI.new(source_node_url), RDF.type, RDF::DCMIType.Image]).size).to eql 1
      
      # the selector node object / ttl
      selector_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSelector, :selector_node]).first.object.to_s
      expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url selector_node_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      selector_obj = RDF::URI.new(selector_node_url)
      expect(g.query([selector_obj, RDF.type, RDF::OpenAnnotation.FragmentSelector]).size).to eql 1
      expect(g.query([selector_obj, RDF.value, RDF::Literal.new("xywh=0,0,200,200")]).size).to eql 1
      expect(g.query([selector_obj, RDF::DC.conformsTo, RDF::URI.new("http://www.w3.org/TR/media-frags/")]).size).to eql 1
    end
    it 'target html frag selector' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_target_container
      target_uuids = my_svc.create_target_resources 
      expect(target_uuids.size).to eql 1
      target_obj_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t/#{target_uuids[0]}"
      resp = conn.get do |req|
        req.url target_obj_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      target_obj = RDF::URI.new(target_obj_url)
      expect(g.query([target_obj, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
      source_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSource, :source_node]).first.object.to_s
      # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
      expect(source_node_url).to match "#{target_obj_url}#source"
      expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq131cs7229.html")]).size).to eql 1
      
      # the selector node object / ttl
      selector_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSelector, :selector_node]).first.object.to_s
      expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url selector_node_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      selector_obj = RDF::URI.new(selector_node_url)
      expect(g.query([selector_obj, RDF.type, RDF::OpenAnnotation.TextQuoteSelector]).size).to eql 1
      expect(g.query([selector_obj, RDF::OpenAnnotation.suffix, RDF::Literal.new(" and The Canonical Epistles,")]).size).to eql 1
      expect(g.query([selector_obj, RDF::OpenAnnotation.exact, RDF::Literal.new("third and fourth Gospels")]).size).to eql 1
      expect(g.query([selector_obj, RDF::OpenAnnotation.prefix, RDF::Literal.new("manuscript which comprised the ")]).size).to eql 1
    end
    it 'mult targets (simple URIs)' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "hasTarget": [
          "http://purl.stanford.edu/kq131cs7229",
          "http://purl.stanford.edu/oo000oo1234"
        ]
      }'
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_target_container
      target_uuids = my_svc.create_target_resources 
      expect(target_uuids.size).to eql 2
      
      container_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::LDP.contains, nil]).size).to eql 2

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
    it 'mult targets (URIs with addl properties)' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_target_container
      target_uuids = my_svc.create_target_resources 
      expect(target_uuids.size).to eql 3
      
      container_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::LDP.contains, nil]).size).to eql 3
      
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
      expect(g.query([RDF::URI.new(second_target_url), RDF.type, RDF::DCMIType.Image]).size).to eql 1
      
      third_target_url = "#{container_url}/#{target_uuids[2]}"
      resp = conn.get do |req|
        req.url third_target_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      expect(g.query([RDF::URI.new(third_target_url), RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")]).size).to eql 1
      expect(g.query([RDF::URI.new(third_target_url), RDF.type, RDF::DCMIType.Image]).size).to eql 1
    end
    it 'mult target blank nodes' do
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
      my_svc = Triannon::LdpCreator.new my_anno
      new_pid = my_svc.create_base
      my_svc.create_target_container
      target_uuids = my_svc.create_target_resources 
      expect(target_uuids.size).to eql 3
      
      container_url = "#{Triannon.config[:ldp_url]}/#{new_pid}/t"
      container_resp = conn.get do |req|
        req.url container_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(container_resp.body)
      expect(g.query([RDF::URI.new(container_url), RDF::LDP.contains, nil]).size).to eql 3
      
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
      target_obj = RDF::URI.new(second_target_url)
      expect(g.query([target_obj, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
      source_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSource, :source_node]).first.object.to_s
      # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
      expect(source_node_url).to match "#{second_target_url}#source"
      expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("http://purl.stanford.edu/kq666cs6666.html")]).size).to eql 1
      
      # the selector node object / ttl
      selector_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSelector, :selector_node]).first.object.to_s
      expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url selector_node_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      selector_obj = RDF::URI.new(selector_node_url)
      expect(g.query([selector_obj, RDF.type, RDF::OpenAnnotation.TextPositionSelector]).size).to eql 1
      expect(g.query([selector_obj, RDF::OpenAnnotation.start, RDF::Literal.new(0)]).size).to eql 1
      expect(g.query([selector_obj, RDF::OpenAnnotation.end, RDF::Literal.new(66)]).size).to eql 1
      
      
      third_target_url = "#{container_url}/#{target_uuids[2]}"
      resp = conn.get do |req|
        req.url third_target_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      target_obj = RDF::URI.new(third_target_url)
      expect(g.query([target_obj, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
      source_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSource, :source_node]).first.object.to_s
      # it's a hashURI so it's in the same response due to fcrepo4 implementation of hash URI nodes
      expect(source_node_url).to match "#{third_target_url}#source"
      expect(g.query([RDF::URI.new(source_node_url), RDF::Triannon.externalReference, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")]).size).to eql 1
      expect(g.query([RDF::URI.new(source_node_url), RDF.type, RDF::DCMIType.Image]).size).to eql 1
      
      # the selector node object / ttl
      selector_node_url = g.query([target_obj, RDF::OpenAnnotation.hasSelector, :selector_node]).first.object.to_s
      expect(selector_node_url).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url selector_node_url
        req.headers['Accept'] = 'application/x-turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      selector_obj = RDF::URI.new(selector_node_url)
      expect(g.query([selector_obj, RDF.type, RDF::OpenAnnotation.FragmentSelector]).size).to eql 1
      expect(g.query([selector_obj, RDF.value, RDF::Literal.new("xywh=0,0,200,200")]).size).to eql 1
      expect(g.query([selector_obj, RDF::DC.conformsTo, RDF::URI.new("http://www.w3.org/TR/media-frags/")]).size).to eql 1      
    end    

    it "DataPositionSelector" do
      skip 'DataPositionSelector not yet implemented'
    end
    it "SvgSelector" do
      skip 'SvgSelector not yet implemented'
    end
    
  end # create_target_resources

  describe '#create_direct_container' do
    let(:svc) { Triannon::LdpCreator.new anno }
    let(:conn) { Faraday.new(:url => Triannon.config[:ldp_url]) }
    before(:each) do
      @new_pid = svc.create_base
    end
    it 'LDP store creates retrievable, empty LDP DirectContainer with expected id and LDP member relationships' do
      svc.send(:create_direct_container, RDF::OpenAnnotation.hasTarget)
      cont_url = "#{@new_pid}/t"
      resp = conn.get do |req|
        req.url cont_url
        req.headers['Accept'] = 'text/turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_cont_url = "#{Triannon.config[:ldp_url]}/#{cont_url}"
      expect(g.query([RDF::URI.new(full_cont_url), RDF.type, RDF::LDP.DirectContainer]).size).to eql 1
      expect(g.query([RDF::URI.new(full_cont_url), RDF::LDP.membershipResource, RDF::URI.new("#{Triannon.config[:ldp_url]}/#{@new_pid}")]).size).to eql 1
      expect(g.query([RDF::URI.new(full_cont_url), RDF::LDP.hasMemberRelation, RDF::OpenAnnotation.hasTarget]).size).to eql 1
    end
    it 'has the correct ldp:memberRelation and id for hasTarget' do
      # see previous spec
    end
    it 'has the correct ldp:memberRelation and id for hasBody' do
      svc.send(:create_direct_container, RDF::OpenAnnotation.hasBody)
      resp = conn.get do |req|
        req.url "#{@new_pid}/b"
        req.headers['Accept'] = 'text/turtle'
      end
      g = RDF::Graph.new
      g.from_ttl(resp.body)
      full_cont_url = "#{Triannon.config[:ldp_url]}/#{@new_pid}/b"
      expect(g.query([RDF::URI.new(full_cont_url), RDF::LDP.hasMemberRelation, RDF::OpenAnnotation.hasBody]).size).to eql 1
    end
  end

  describe '#subject_statements' do
    it 'returns appropriate blank node statements when the subject is an RDF::Node in the graph' do
      graph = RDF::Graph.new
      graph.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasBody> [
           a <http://www.w3.org/2011/content#ContentAsText>,
             <http://purl.org/dc/dcmitype/Text>;
           <http://www.w3.org/2011/content#chars> "I love this!"
         ] .')
      body_resource = graph.query([nil, RDF::OpenAnnotation.hasBody, nil]).first.object
      body_stmts = Triannon::LdpCreator.subject_statements(body_resource, graph)
      expect(body_stmts.size).to eql 3
      expect(body_stmts).to include([body_resource, RDF::Content::chars, "I love this!"])
      expect(body_stmts).to include([body_resource, RDF.type, RDF::Content.ContentAsText])
      expect(body_stmts).to include([body_resource, RDF.type, RDF::DCMIType.Text])
    end
    it 'recurses to get triples from objects of the subject statements' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSource": "http://purl.stanford.edu/kq131cs7229.html",
          "hasSelector": {
            "@type": "oa:TextPositionSelector",
            "start": 0,
            "end": 66
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::LdpCreator.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 6
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, "http://purl.stanford.edu/kq131cs7229.html"])
      selector_resource =  graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource])
      expect(target_stmts).to include([selector_resource, RDF.type, RDF::OpenAnnotation.TextPositionSelector])
      expect(target_stmts).to include([selector_resource, RDF::OpenAnnotation.start, RDF::Literal.new(0)])
      expect(target_stmts).to include([selector_resource, RDF::OpenAnnotation.end, RDF::Literal.new(66)])

      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSelector": {
            "@type": "oa:FragmentSelector",
            "value": "xywh=0,0,200,200",
            "conformsTo": "http://www.w3.org/TR/media-frags/"
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::LdpCreator.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 5
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      selector_resource =  graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource])
      expect(target_stmts).to include([selector_resource, RDF.type, RDF::OpenAnnotation.FragmentSelector])
      expect(target_stmts).to include([selector_resource, RDF.value, RDF::Literal.new("xywh=0,0,200,200")])
      expect(target_stmts).to include([selector_resource, RDF::DC.conformsTo, "http://www.w3.org/TR/media-frags/"])
    end
    it 'finds all properties of URI nodes' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSource": {
            "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg",
            "@type": "dctypes:Image"
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::LdpCreator.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 3
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"])
      source_resource = graph.query([target_resource, RDF::OpenAnnotation.hasSource, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, source_resource])
      expect(target_stmts).to include([source_resource, RDF.type, RDF::DCMIType.Image])
    end
    it 'empty Array when the subject is not in the graph' do
      graph = RDF::Graph.new
      graph.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasBody> [
           a <http://www.w3.org/2011/content#ContentAsText>,
             <http://purl.org/dc/dcmitype/Text>;
           <http://www.w3.org/2011/content#chars> "I love this!"
         ] .')
      expect(Triannon::LdpCreator.subject_statements(RDF::Node.new, graph)).to eql []
      expect(Triannon::LdpCreator.subject_statements(RDF::URI.new("http://not.there.org"), graph)).to eql []
    end
    it 'empty Array when the subject is an RDF::URI with no additional properties' do
      graph = RDF::Graph.new
      graph.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>.')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      expect(target_resource).to be_a RDF::URI
      expect(Triannon::LdpCreator.subject_statements(target_resource, graph)).to eql []
    end
    it 'empty Array when subject is not RDF::Node or RDF::URI' do
      graph = RDF::Graph.new
      graph.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>.')
      expect(Triannon::LdpCreator.subject_statements(RDF.type, graph)).to eql []
    end
  end

end