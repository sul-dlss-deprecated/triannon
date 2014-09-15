require 'spec_helper'

describe Cerberus::Annotations::Annotation do
  it "should deserialize json-ld annotations" do
    annotation = Cerberus::Annotations::Annotation.new data: annotation_fixture("annotation-comment-as-text-chars.json")
    expect(annotation.graph).to be_a_kind_of RDF::Graph
  end

  def annotation_fixture fixture
    File.read Cerberus::Annotations.fixture_path("annotations/#{fixture}")
  end
end
