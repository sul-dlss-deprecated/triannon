require 'spec_helper'

describe Cerberus::Annotations::Annotation do
  
  before(:each) do
    @anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("annotation-bookmarking.json")
  end
  
  it "deserializes json-ld annotations" do
    expect(@anno).not_to eql(nil)
  end
  
  it "id is the @id of the json" do
    expect(@anno.id).to eql("http://example.org/annos/annotation/12.json")
  end

  it "url is an alias for id" do
    expect(@anno.url).to eql("http://example.org/annos/annotation/12.json")
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
  
  it "motivated_by" do
    expect(@anno.motivated_by).to eql("http://www.w3.org/ns/oa#bookmarking")
  end

  def annotation_fixture fixture
    File.read Cerberus::Annotations.fixture_path("annotations/#{fixture}")
  end
end
