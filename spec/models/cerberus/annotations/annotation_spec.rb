require 'spec_helper'

describe Cerberus::Annotations::Annotation do
  
  context "json from fixture" do
    before(:each) do
      @anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("annotation-bookmarking.json")
    end

    it "deserializes json-ld annotations" do
      expect(@anno).not_to eql(nil)
    end

    it "type is oa:Annotation" do
      expect(@anno.type).to eql("http://www.w3.org/ns/oa#Annotation")
    end
    it "url is the @id of the json" do
      expect(@anno.url).to eql("http://example.org/annos/annotation/12.json")
    end
    it "has_target when URL" do
      expect(@anno.has_target).to eql("http://purl.stanford.edu/kq131cs7229")
    end
    it "has_body missing" do
      expect(@anno.has_body).to be_nil
    end
    it "has_body when blank node with text" do
      anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("annotation-comment-as-text-chars.json")
      expect(anno.has_body).to eql("I love this!")
      anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("annotation-multiple-targets.json")
      expect(anno.has_body).to eql("I love these two things!")
    end
    it "motivated_by" do
      expect(@anno.motivated_by).to eql("http://www.w3.org/ns/oa#bookmarking")
    end
    it "graph is populated RDF::Graph" do
      expect(@anno.graph).to be_a_kind_of RDF::Graph
      expect(@anno.graph.count).to be > 0
    end
    it "rdf is populated Array of RDF statments" do
      expect(@anno.rdf).to be_a_kind_of Array
      expect(@anno.rdf.size).to be > 0
      expect(@anno.rdf[0].class).to eql(RDF::Statement)
    end
  end # json from fixture

  def annotation_fixture fixture
    File.read Cerberus::Annotations.fixture_path("annotations/#{fixture}")
  end
end
