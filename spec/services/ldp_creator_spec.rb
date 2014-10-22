require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

vcr_options = {:re_record_interval => 45.days}  # TODO will make shorter once we have jetty running fedora4
describe Triannon::LdpCreator, :vcr => vcr_options do

  let(:anno) { Triannon::Annotation.new data: Triannon.annotation_fixture("body-chars.ttl") }
  let(:svc) { Triannon::LdpCreator.new anno }
  let(:conn) { Faraday.new(:url => Triannon.config[:ldp_url]) }

  describe "#create_base" do
    it 'LDP store creates retrievable object representing the annotation and returns id' do
      new_pid = svc.create_base
      resp = conn.get do |req|
        req.url "#{new_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      expect(resp.body).to match /oa#Annotation/
      expect(resp.body).to match /oa#motivatedBy/
      expect(resp.body).to match /oa#commenting/
    end
    it 'keeps multiple motivations if present' do
      my_anno = Triannon::Annotation.new data: '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@id": "http://example.org/annos/annotation/mult-motivations.json", 
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
      expect(resp.body).to match /oa#Annotation/
      expect(resp.body).to match /oa#motivatedBy/
      expect(resp.body).to match /oa#moderating/
      expect(resp.body).to match /oa#tagging/
    end
    it 'posts provenance if present' do
      skip "provenance not yet implemented"
    end
  end

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
      expect(resp.body).to match /ldp#membershipResource/
      expect(resp.body).to match /#{new_pid}/
      expect(resp.body).to match /ldp#hasMemberRelation/
      expect(resp.body).to match /oa#hasBody/
      expect(resp.body).not_to match /ldp#contains/
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
      expect(resp.body).to match /ldp#membershipResource/
      expect(resp.body).to match /#{new_pid}/
      expect(resp.body).to match /ldp#hasMemberRelation/
      expect(resp.body).to match /oa#hasTarget/
      expect(resp.body).not_to match /ldp#contains/
    end
  end

  # OLD
  describe "#create_body" do
    it "POSTS a ttl representation of a body to the body container" do
      new_pid = svc.create_base
      svc.create_body_container
      body_pid = svc.create_body

      resp = conn.get do |req|
        req.url " #{new_pid}/b/#{body_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      expect(resp.body).to match /I love this/
      expect(resp.body).to match /#{new_pid}/
    end
  end

  # OLD
  describe "#create_target" do
    it "POSTS a ttl representation of a target to the target container" do
      new_pid = svc.create_base
      svc.create_target_container
      target_pid = svc.create_target

      resp = conn.get do |req|
        req.url " #{new_pid}/t/#{target_pid}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      expect(resp.body).to match /purl.stanford.edu/
      expect(resp.body).to match /triannon.*\/externalReference/
    end
  end

  # OLD
  describe ".create Class method" do
    it "creates an entire Annotation vi LDP and returns the pid" do
      id = Triannon::LdpCreator.create anno

      resp = conn.get do |req|
        req.url " #{id}"
        req.headers['Accept'] = 'application/x-turtle'
      end
      expect(resp.body).to match /hasBody/
      expect(resp.body).to match /hasTarget/
    end
  end
  
  describe '.create_from_graph' do
    it 'should not create a body container if there are no bodies' do
      skip
    end
    it 'should create a single body container with multiple resources if there are multiple bodies' do
      skip
    end
    it 'should create a single target container with multiple resources if there are multiple targets' do
      skip
    end
    it 'should call create_body_resource for each body resource' do
      skip
    end
    it 'should call create_target_resource for each target resource' do
      skip
    end
    it 'should create something or other for external resources' do
      skip
    end
  end
  
  describe '#create_body_resources' do
    it 'creates resources in the body container' do
      new_pid = svc.create_base
      svc.create_body_container
      body_uuid = svc.create_body_resources Triannon::LdpCreator.bodies_graph(anno.graph)
      body_pid = "#{new_pid}/b/#{body_uuid}"
      body_resp = conn.get do |req|
        req.url body_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      expect(body_resp.body).to match /cnt\:ContentAsText/
      expect(body_resp.body).to match /\:Text/
      expect(body_resp.body).to match /chars "I love this!"/
      
      body_container_id = "#{Triannon.config[:ldp_url]}/#{new_pid}/b"
      body_container_resp = conn.get do |req|
        req.url body_container_id
        req.headers['Accept'] = 'application/x-turtle'
      end
      expect(body_container_resp.body).to match /ldp:contains/
      expect(body_container_resp.body).to match body_pid
    end
    it 'creates all appropriate statements for has_body blank nodes, recursively' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "hasBody": {
          "@type": [
            "cnt:ContentAsText", 
            "dctypes:Text"
          ], 
          "chars": "I love this!",
          "language": "en"
        } 
      }')
      new_pid = svc.create_base
      svc.create_body_container
      body_uuid = svc.create_body_resources Triannon::LdpCreator.bodies_graph(graph)
      body_pid = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuid}"
      body_resp = conn.get do |req|
        req.url body_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      expect(body_resp.body).to match /cnt\:ContentAsText/
      expect(body_resp.body).to match /\:Text/
      expect(body_resp.body).to match /chars "I love this!"/
      expect(body_resp.body).to match /language "en"/
    end
    it 'contains all appropriate statements for has_body blank nodes, recursively, oa:Choice' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
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
      }')
      new_pid = svc.create_base
      svc.create_body_container
      body_uuid = svc.create_body_resources Triannon::LdpCreator.bodies_graph(graph)
      body_pid = "#{Triannon.config[:ldp_url]}/#{new_pid}/b/#{body_uuid}"
      body_resp = conn.get do |req|
        req.url body_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      expect(body_resp.body).to match /:Choice/
      expect(body_resp.body).to match /:default/
      expect(body_resp.body).to match /:item/
      
      # find the default blank node object / ttl
      g = RDF::Graph.new
      g.from_ttl body_resp.body
      stmts = g.query([RDF::URI.new(body_pid), RDF::OpenAnnotation.default, :default_blank_node])
      expect(stmts.size).to eql 1
      default_node_pid = stmts.first.object.to_s
      expect(default_node_pid).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url default_node_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      default_node_ttl = resp.body
      expect(default_node_ttl).to match /cnt\:ContentAsText/
      expect(default_node_ttl).to match /:Text/
      expect(default_node_ttl).to match /:default/
      expect(default_node_ttl).to match /language "en"/
      expect(default_node_ttl).to match /chars\s+"I love this Englishly!/

      # find the item blank node object / ttl
      g = RDF::Graph.new
      g.from_ttl body_resp.body
      stmts = g.query([RDF::URI.new(body_pid), RDF::OpenAnnotation.item, :item_blank_node])
      expect(stmts.size).to eql 1
      item_node_pid = stmts.first.object.to_s
      expect(item_node_pid).to match /\/.well-known\//  # this is a fcrepo4 implementation of inner blank nodes
      resp = conn.get do |req|
        req.url item_node_pid
        req.headers['Accept'] = 'application/x-turtle'
      end
      item_node_ttl = resp.body
      expect(item_node_ttl).to match /cnt\:ContentAsText/
      expect(item_node_ttl).to match /:Text/
      expect(item_node_ttl).to match /:item/
      expect(item_node_ttl).to match /language "fr"/
      expect(item_node_ttl).to match /chars "Je l'aime en Francais!"/
    end
    it 'does the right thing when the body is a simple URI' do
      skip
    end
    it 'creates any additional properties associated with a body URI' do
      skip
    end
    it 'creates multiple bodies properly' do
      skip
    end
  end
  
  describe '#create_direct_container' do
    let(:svc) { Triannon::LdpCreator.new anno }
    let(:conn) { Faraday.new(:url => Triannon.config[:ldp_url]) }
    before(:each) do
      @new_pid = svc.create_base
    end
    it 'LDP store creates retrievable, empty LDP DirectContainer with expected id and LDP member relationships' do
      svc.send(:create_direct_container, RDF::OpenAnnotation.hasTarget)
      resp = conn.get do |req|
        req.url " #{@new_pid}/t"
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.body).to match /DirectContainer/
      expect(resp.body).to match /membershipResource/
      expect(resp.body).to match  "#{Triannon.config[:ldp_url]}/#{@new_pid}"
      expect(resp.body).to match /hasMemberRelation/
      expect(resp.body).to match /hasTarget/
    end
    it 'has the correct ldp:memberRelation and id for hasTarget' do
      # see previous spec
    end
    it 'has the correct ldp:memberRelation and id for hasBody' do
      svc.send(:create_direct_container, RDF::OpenAnnotation.hasBody)
      resp = conn.get do |req|
        req.url " #{@new_pid}/b"
        req.headers['Accept'] = 'text/turtle'
      end
      expect(resp.body).to match /hasBody/
    end
  end

  describe '#bodies_graph' do
    it 'empty when no bodies' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "motivatedBy": "oa:bookmarking", 
        "hasTarget": "http://purl.stanford.edu/kq131cs7229"
      }')
      bodies_graph = Triannon::LdpCreator.bodies_graph graph
      expect(bodies_graph).to be_a RDF::Graph
      expect(bodies_graph.size).to eql 0
    end
    it 'contains all appropriate statements for has_body blank nodes, recursively' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "hasBody": {
          "@type": [
            "cnt:ContentAsText", 
            "dctypes:Text"
          ], 
          "chars": "I love this!",
          "language": "en"
        } 
      }')
      bodies_graph = Triannon::LdpCreator.bodies_graph graph
      expect(bodies_graph).to be_a RDF::Graph
      expect(bodies_graph.size).to eql 4
      body_resource = graph.query([nil, RDF::OpenAnnotation.hasBody, nil]).first.object
      expect(bodies_graph.query([nil, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(bodies_graph.query([nil, RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(bodies_graph.query([nil, RDF::Content.chars, RDF::Literal.new("I love this!")]).size).to eql 1
      expect(bodies_graph.query([nil, RDF::DC11.language, RDF::Literal.new("en")]).size).to eql 1
    end

    it 'contains all appropriate statements for has_body blank nodes, recursively, oa:Choice' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
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
      }')
      bodies_graph = Triannon::LdpCreator.bodies_graph graph
      expect(bodies_graph).to be_a RDF::Graph
      expect(bodies_graph.size).to eql 11
      body_resource = graph.query([nil, RDF::OpenAnnotation.hasBody, nil]).first.object
      expect(bodies_graph.query([body_resource, RDF.type, RDF::OpenAnnotation.Choice]).size).to eql 1
      expect(bodies_graph.query([body_resource, RDF::OpenAnnotation.default, nil]).size).to eql 1
      expect(bodies_graph.query([body_resource, RDF::OpenAnnotation.item, nil]).size).to eql 1
      default_body_node = bodies_graph.query([body_resource, RDF::OpenAnnotation.default, nil]).first.object
      expect(bodies_graph.query([default_body_node, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(bodies_graph.query([default_body_node, RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(bodies_graph.query([default_body_node, RDF::Content.chars, RDF::Literal.new("I love this Englishly!")]).size).to eql 1
      expect(bodies_graph.query([default_body_node, RDF::DC11.language, RDF::Literal.new("en")]).size).to eql 1
      item_body_node = bodies_graph.query([body_resource, RDF::OpenAnnotation.item, nil]).first.object
      expect(bodies_graph.query([item_body_node, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(bodies_graph.query([item_body_node, RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(bodies_graph.query([item_body_node, RDF::Content.chars, RDF::Literal.new("Je l'aime en Francais!")]).size).to eql 1
      expect(bodies_graph.query([item_body_node, RDF::DC11.language, RDF::Literal.new("fr")]).size).to eql 1
    end
    it 'empty when body is URI with no addl properties' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "hasBody": "http://dbpedia.org/resource/Otto_Ege", 
      }')
      bodies_graph = Triannon::LdpCreator.bodies_graph graph
      expect(bodies_graph).to be_a RDF::Graph
      expect(bodies_graph.size).to eql 0
    end
    it 'includes any addl properties of body URI nodes' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "hasBody": {
          "@id": "http://www.example.org/comment.pdf", 
          "@type": "dctypes:Text"
        }
      }')
      bodies_graph = Triannon::LdpCreator.bodies_graph graph
      expect(bodies_graph).to be_a RDF::Graph
      expect(bodies_graph.size).to eql 1
      body_resource = graph.query([nil, RDF::OpenAnnotation.hasBody, nil]).first.object
      expect(bodies_graph.query([body_resource, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    end
    it 'multiple bodies' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
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
      }')
      bodies_graph = Triannon::LdpCreator.bodies_graph graph
      expect(bodies_graph).to be_a RDF::Graph
      expect(bodies_graph.size).to eql 4
      first_body = graph.query([nil, RDF::OpenAnnotation.hasBody, nil]).first.object
      second_body = graph.query([nil, RDF::OpenAnnotation.hasBody, nil]).to_a[1].object
      expect(bodies_graph.query([first_body, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
      expect(bodies_graph.query([first_body, RDF.type, RDF::DCMIType.Text]).size).to eql 1
      expect(bodies_graph.query([first_body, RDF::Content.chars, RDF::Literal.new("I love this!")]).size).to eql 1
      expect(bodies_graph.query([second_body, RDF.type, RDF::OpenAnnotation.SemanticTag]).size).to eql 1
    end
  end
  
  describe '#targets_graph' do
    it 'empty when target is URI with no addl properties' do
      graph = RDF::Graph.new
      graph.from_ttl('<> <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>.')
      targets_graph = Triannon::LdpCreator.targets_graph graph
      expect(targets_graph).to be_a RDF::Graph
      expect(targets_graph.size).to eql 0
    end
    it 'includes any addl properties of target URI nodes' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@type": "oa:Annotation", 
        "hasTarget": {
          "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg#xywh=0,0,200,200", 
          "@type": "dctypes:Image"
        }
      }')
      targets_graph = Triannon::LdpCreator.targets_graph graph
      expect(targets_graph).to be_a RDF::Graph
      expect(targets_graph.size).to eql 1
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      expect(targets_graph.query([target_resource, RDF.type, RDF::DCMIType.Image]).size).to eql 1
    end
    it 'contains all appropriate statements for has_target blank nodes, recursively' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
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
      }')
      targets_graph = Triannon::LdpCreator.targets_graph graph
      expect(targets_graph).to be_a RDF::Graph
      expect(targets_graph.size).to eql 6
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      expect(targets_graph.query([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
      expect(targets_graph.query([target_resource, RDF::OpenAnnotation.hasSource, RDF::URI.new("http://purl.stanford.edu/kq131cs7229.html")]).size).to eql 1
      selector_resource = graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(targets_graph.query([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF.type, RDF::OpenAnnotation.TextPositionSelector]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF::OpenAnnotation.start, RDF::Literal.new(0)]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF::OpenAnnotation.end, RDF::Literal.new(66)]).size).to eql 1
    end
    it 'multiple blank nodes at target second level' do
      graph = RDF::Graph.new
      graph.from_jsonld('{  
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
      }')
      targets_graph = Triannon::LdpCreator.targets_graph graph
      expect(targets_graph).to be_a RDF::Graph
      expect(targets_graph.size).to eql 7
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      expect(targets_graph.query([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
      source_resource = graph.query([target_resource, RDF::OpenAnnotation.hasSource, nil]).first.object
      expect(targets_graph.query([target_resource, RDF::OpenAnnotation.hasSource, RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")]).size).to eql 1
      expect(targets_graph.query([target_resource, RDF::OpenAnnotation.hasSource, source_resource]).size).to eql 1
      expect(targets_graph.query([source_resource, RDF.type, RDF::DCMIType.Image]).size).to eql 1
      selector_resource = graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(targets_graph.query([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF.type, RDF::OpenAnnotation.FragmentSelector]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF.value, RDF::Literal.new("xywh=0,0,200,200")]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF::DC.conformsTo, RDF::URI.new("http://www.w3.org/TR/media-frags/")]).size).to eql 1
    end
    it 'target is html frag selector' do
      graph = RDF::Graph.new
      graph.from_jsonld('{  
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
      }')
      targets_graph = Triannon::LdpCreator.targets_graph graph
      expect(targets_graph).to be_a RDF::Graph
      expect(targets_graph.size).to eql 7
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      expect(targets_graph.query([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
      expect(targets_graph.query([target_resource, RDF::OpenAnnotation.hasSource, RDF::URI.new("http://purl.stanford.edu/kq131cs7229.html")]).size).to eql 1
      selector_resource = graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(targets_graph.query([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF.type, RDF::OpenAnnotation.TextQuoteSelector]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF::OpenAnnotation.suffix, RDF::Literal.new(" and The Canonical Epistles,")]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF::OpenAnnotation.exact, RDF::Literal.new("third and fourth Gospels")]).size).to eql 1
      expect(targets_graph.query([selector_resource, RDF::OpenAnnotation.prefix, RDF::Literal.new("manuscript which comprised the ")]).size).to eql 1
    end
    it 'multiple targets' do
      graph = RDF::Graph.new
      graph.from_jsonld('{
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
      }')
      has_target_stmts = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      expect(has_target_stmts.size).to eql 3
      targets_graph = Triannon::LdpCreator.targets_graph graph
      expect(targets_graph).to be_a RDF::Graph
      expect(targets_graph.size).to eql 2
      expect(targets_graph.query([RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"), RDF.type, RDF::DCMIType.Image]).size).to eql 1
      expect(targets_graph.query([RDF::URI.new("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_thumb.jpg"), RDF.type, RDF::DCMIType.Image]).size).to eql 1
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