require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

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

    it "sets the hasTarget url from externalReference" do
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.extract_target

      res = mapper.oa_graph.query [nil, RDF::OpenAnnotation.hasTarget, nil]
      expect(res.count).to eq 1
      uri = res.first.object
      expect(uri.class).to eq RDF::URI
      expect(uri.to_s).to match /purl.stanford.edu\/kq131cs7229/
    end
  end

end
