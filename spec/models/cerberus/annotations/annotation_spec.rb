require 'spec_helper'

describe Cerberus::Annotations::Annotation do
  
  before(:each) do
    @anno = Cerberus::Annotations::Annotation.new data: annotation_fixture("annotation-bookmarking.json")
  end
  
  it "deserializes json-ld annotations" do
    expect(@anno).not_to eql(nil)
  end
  
  it "graph is populated RDF::Graph" do
    expect(@anno.graph).to be_a_kind_of RDF::Graph
    expect(@anno.graph.count).to be > 0
  end

  def annotation_fixture fixture
    File.read Cerberus::Annotations.fixture_path("annotations/#{fixture}")
  end
end
