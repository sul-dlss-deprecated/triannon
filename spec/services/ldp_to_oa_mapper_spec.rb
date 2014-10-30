require 'spec_helper'

describe Triannon::LdpToOaMapper do
  let(:anno_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_base.ttl') }
  let(:base_stmts) { RDF::Graph.new.from_ttl(anno_ttl).statements }
  let(:body_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_body.ttl') }
  let(:body_stmts) { RDF::Graph.new.from_ttl(body_ttl).statements }
  let(:target_ttl) { File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_target.ttl') }
  let(:target_stmts) { RDF::Graph.new.from_ttl(target_ttl).statements }

  describe ".ldp_to_oa" do

    it "maps an AnnotationLdp to an OA RDF::Graph" do
      ldp_anno = Triannon::AnnotationLdp.new
      ldp_anno.load_statements_into_graph base_stmts
      ldp_anno.load_statements_into_graph body_stmts
      ldp_anno.load_statements_into_graph target_stmts
      oa_graph = Triannon::LdpToOaMapper.ldp_to_oa ldp_anno

      resp = oa_graph.query [nil,RDF.type, RDF::OpenAnnotation.Annotation ]
      expect(resp.first.subject.to_s).to eq "#{Triannon.config[:triannon_base_url]}/deb27887-1241-4ccc-a09c-439293d73fbb"
    end

  end

  describe "#extract_base" do
    let(:ldp_anno) {
      a = Triannon::AnnotationLdp.new
      a.load_statements_into_graph base_stmts
      a
    }

    let(:mapper) { Triannon::LdpToOaMapper.new ldp_anno  }

    # TODO what to do about id in the graph?  Config option? Config.open_annotation_base_uri ?
    it "extracts the id from the root subject" do
      mapper.extract_base
      expect(mapper.id).to eq 'deb27887-1241-4ccc-a09c-439293d73fbb'
    end

    it "builds the base identifier from the Config.open_annotation.base_uri and @id" do
      mapper.extract_base
      resp = mapper.oa_graph.query [nil,RDF.type, RDF::OpenAnnotation.Annotation ]
      expect(resp.first.subject.to_s).to eq "#{Triannon.config[:triannon_base_url]}/deb27887-1241-4ccc-a09c-439293d73fbb"
    end

    it "checks the RDF.type to be RDF::OpenAnnotation.Annotation" do
      skip "raise an exception if it is not?"
    end

    it "extracts the motivations" do
      mapper.extract_base

      res = mapper.oa_graph.query [nil, RDF::OpenAnnotation.motivatedBy, nil]
      expect(res.count).to eq 1
      expect(res.first.object).to eq RDF::OpenAnnotation.commenting
    end
  end

  describe "#extract_body" do
    context "when the RDF.type is ContentAsText" do
      let(:ldp_anno) {
        a = Triannon::AnnotationLdp.new
        a.load_statements_into_graph base_stmts
        a.load_statements_into_graph body_stmts
        a
      }

      it "sets the hasBody statement with a blank node of type ContentAsText, dcmitype/Text with content#chars" do
        mapper = Triannon::LdpToOaMapper.new ldp_anno
        mapper.extract_base
        mapper.extract_body

        res = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasBody, nil]
        expect(res.count).to eq 1
        body_node = res.first.object
        res = mapper.oa_graph.query [body_node, RDF.type, RDF::Content.ContentAsText]
        expect(res.count).to eq 1
        res = mapper.oa_graph.query [body_node, RDF.type, RDF::DCMIType.Text]
        expect(res.count).to eq 1
        res = mapper.oa_graph.query [body_node, RDF::Content.chars, nil]
        expect(res.first.object.to_s).to match /I love this!/
      end
    end

  end

  describe "#extract_target" do
    let(:ldp_anno) {
      a = Triannon::AnnotationLdp.new
      a.load_statements_into_graph base_stmts
      a.load_statements_into_graph target_stmts
      a
    }
    let(:target_url) { "http://purl.stanford.edu/kq131cs7229" }

    it "sets the hasTarget url from externalReference" do
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.extract_target

      res = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(res.count).to eq 1
      uri = res.first.object
      expect(uri.class).to eq RDF::URI
      expect(uri.to_s).to eql target_url
    end
  end
  
  describe '#map_external_ref' do
    let(:ldp_anno) {
      a = Triannon::AnnotationLdp.new
      a.load_statements_into_graph base_stmts
      a
    }
    let(:target_url) { "http://purl.stanford.edu/kq131cs7229" }
    it "adds statement with external uri from externalReference statement to oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 0
      
      target_uri = ldp_anno.target_uris.first
      mapper.map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget)
      
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 1
      uri = solns.first.object
      expect(uri.class).to eq RDF::URI
      expect(uri.to_s).to eql target_url
    end
    it "returns true if it adds statements to oa_graph" do
      ldp_anno.load_statements_into_graph target_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 0
      
      target_uri = ldp_anno.target_uris.first
      expect(mapper.map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget)).to be true
    end
    it "returns false if it doesn't change oa_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 0
      
      body_uri = ldp_anno.body_uris.first
      expect(mapper.map_external_ref(body_uri, RDF::OpenAnnotation.hasTarget)).to be false
    end
    it "doesn't change @oa_graph if there is no Triannon:externalReference in @ldp_anno_graph" do
      ldp_anno.load_statements_into_graph body_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 0
      
      body_uri = ldp_anno.body_uris.first
      mapper.map_external_ref(body_uri, RDF::OpenAnnotation.hasTarget)
      
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 0
    end
    it "only maps the first Triannon:externalReference if there is more than one in the container" do
      # there should only ever be one Triannon:externalReference in the object LDP container
      target_url1 = target_url
      target_url2 = "http://purl.stanford.edu/ab123cd4567"
      target_ttl = "
        <http://localhost:8983/fedora/rest/anno/deb27887-1241-4ccc-a09c-439293d73fbb/t/ee774031-74d9-4f5a-9b03-cdd21267e4e1> 
        <http://triannon.stanford.edu/ns/externalReference> <#{target_url1}>, <#{target_url2}>; ."
      my_target_stmts = RDF::Graph.new.from_ttl(target_ttl).statements
      ldp_anno.load_statements_into_graph my_target_stmts
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(solns.count).to eq 0
      
      target_uri = ldp_anno.target_uris.first
      mapper.map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget)
      
      solns = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, RDF::URI.new(target_url1)]
      expect(solns.count).to eq 1
      
      solns = mapper.oa_graph.query [nil, nil, RDF::URI.new(target_url2)]
      expect(solns.count).to eq 0
    end
  end

end
