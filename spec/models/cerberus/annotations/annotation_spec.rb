require 'spec_helper'

describe Cerberus::Annotations::Annotation do
  
  context "json from fixture" do
    before(:each) do
      @anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("bookmark.json")
    end

    it "deserializes json-ld annotations" do
      expect(@anno).not_to eql(nil)
    end
    
    context "data_as_graph" do
      context "json data" do
        it "populates graph from json" do
          expect(@anno.graph).to be_a_kind_of RDF::Graph
          expect(@anno.graph.count).to be > 1
        end
        it "converts data to turtle" do
          c = @anno.graph.count
          g = RDF::Graph.new      
          g.from_ttl(@anno.data)
          expect(g.count).to eql c
        end
      end
      context "turtle data" do
        it "populates graph from ttl" do
          anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("body-chars.ttl")
          expect(anno.graph).to be_a_kind_of RDF::Graph
          expect(anno.graph.count).to be > 1
        end
      end
      context "url as data" do
        it "populates graph from url" do
          skip "do we want to load annos from urls?"
          anno = Cerberus::Annotations::Annotation.new data: 'http://example.org/url_to_turtle_anno'
          expect(anno.graph).to be_a_kind_of RDF::Graph
          expect(anno.graph.count).to be > 1
        end
      end
    end
    

    it "type is oa:Annotation" do
      expect(@anno.type).to eql("http://www.w3.org/ns/oa#Annotation")
    end
    it "url is the @id of the json" do
      expect(@anno.url).to eql("http://example.org/annos/annotation/bookmark.json")
    end
    it "has_target when URL" do
      expect(@anno.has_target).to eql("http://purl.stanford.edu/kq131cs7229")
    end
    it "has_body is nil when there is no body" do
      expect(@anno.has_body).to be_nil
    end
    it "has_body is chars when blank node with text" do
      anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("body-chars.json")
      expect(anno.has_body).to eql("I love this!")
      anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("mult-targets.json")
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
