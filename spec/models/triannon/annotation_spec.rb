require 'spec_helper'

vcr_options = { :cassette_name => "models_triannon_annotation" }
describe Triannon::Annotation, :vcr => vcr_options do

  context "json from fixture" do

    context "data_as_graph" do
      context "json data" do
        before(:each) do
          @anno = Triannon::Annotation.new data: annotation_fixture("bookmark.json")
        end
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
          turtle = annotation_fixture("body-chars.ttl")
          expect(turtle).to match(/\.$/)
          anno = Triannon::Annotation.new data: turtle
          expect(anno.graph).to be_a_kind_of RDF::Graph
          expect(anno.graph.count).to be > 1
        end
        it "reject if it doesn't end in period" do
          bad_end = annotation_fixture("body-chars.ttl") + "xxx"
          anno = Triannon::Annotation.new data: bad_end
          expect(anno.graph).to be_nil
        end
      end
      context "url as data" do
        it "populates graph from url" do
          skip "do we want to load annos from urls?"
          anno = Triannon::Annotation.new data: 'http://example.org/url_to_turtle_anno'
          expect(anno.graph).to be_a_kind_of RDF::Graph
          expect(anno.graph.count).to be > 1
        end
      end
    end

    context "parsing graph" do
      before(:each) do
        @anno_json = Triannon::Annotation.new data: annotation_fixture("bookmark.json")
        @anno_ttl = Triannon::Annotation.new data: annotation_fixture("body-chars.ttl")
      end
      it "type is oa:Annotation" do
        expect(@anno_ttl.type).to eql("http://www.w3.org/ns/oa#Annotation")
        expect(@anno_json.type).to eql("http://www.w3.org/ns/oa#Annotation")
        anno = Triannon::Annotation.new data: annotation_fixture("mult-targets.json")
        expect(anno.type).to eql("http://www.w3.org/ns/oa#Annotation")
      end
      it "url" do
        expect(@anno_json.url).to eql("http://example.org/annos/annotation/bookmark.json")
        expect(@anno_ttl.url).to eql("http://example.org/annos/annotation/body-chars.ttl")
        anno = Triannon::Annotation.new data: annotation_fixture("mult-targets.json")
        expect(anno.url).to eql("http://example.org/annos/annotation/mult-targets.json")
      end
      context "has_target" do
        it "single url" do
          expect(@anno_ttl.has_target[0]).to eql("http://purl.stanford.edu/kq131cs7229")
          expect(@anno_json.has_target).to include("http://purl.stanford.edu/kq131cs7229")
        end
        it "multiple urls" do
          anno = Triannon::Annotation.new data: annotation_fixture("mult-targets.json")
          expect(anno.has_target.size).to eql 2
          expect(anno.has_target).to include("http://purl.stanford.edu/kq131cs7229")
          expect(anno.has_target).to include("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")
        end
      end
      context "has_body" do
        it "empty array when there is no body" do
          expect(@anno_json.has_body).not_to be_nil
          expect(@anno_json.has_body.size).to eql 0
        end
        it "text from chars" do
          expect(@anno_ttl.has_body.size).to eql 1
          expect(@anno_ttl.has_body).to include("I love this!")
          anno = Triannon::Annotation.new data: annotation_fixture("body-chars.json")
          expect(anno.has_body.size).to eql 1
          expect(anno.has_body).to include("I love this!")
          anno = Triannon::Annotation.new data: annotation_fixture("body-chars-plain.json")
          expect(anno.has_body.size).to eql 1
          expect(anno.has_body).to include("I love this!")
          anno = Triannon::Annotation.new data: annotation_fixture("body-chars-html.json")
          expect(anno.has_body.size).to eql 1
          expect(anno.has_body).to include("<div xml:lang='en' xmlns='http://www.w3.org/1999/xhtml'>I love this!</div>")
        end
        it "mult targets" do
          anno = Triannon::Annotation.new data: annotation_fixture("mult-targets.json")
          expect(anno.has_body.size).to eql 1
          expect(anno.has_body).to include("I love these two things!")
        end
      end
      context "motivated_by" do
        it "single" do
          expect(@anno_ttl.motivated_by.size).to eql 1
          expect(@anno_ttl.motivated_by[0]).to eql("http://www.w3.org/ns/oa#commenting")
          expect(@anno_json.motivated_by.size).to eql 1
          expect(@anno_json.motivated_by).to include("http://www.w3.org/ns/oa#bookmarking")
        end
        it "multiple" do
          anno = Triannon::Annotation.new data: annotation_fixture("mult-motivations.json")
          expect(anno.motivated_by.size).to eql 2
          expect(anno.motivated_by).to include("http://www.w3.org/ns/oa#moderating")
          expect(anno.motivated_by).to include("http://www.w3.org/ns/oa#tagging")
        end
        it "mult targets" do
          anno = Triannon::Annotation.new data: annotation_fixture("mult-targets.json")
          expect(anno.motivated_by.size).to eql 1
          expect(anno.motivated_by).to include("http://www.w3.org/ns/oa#commenting")
        end
      end
    end
  end # json from fixture

  def annotation_fixture fixture
    File.read Triannon.fixture_path("annotations/#{fixture}")
  end
end
