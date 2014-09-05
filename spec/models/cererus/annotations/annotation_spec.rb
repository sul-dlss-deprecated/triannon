require 'spec_helper'

describe Cerberus::Annotations::Annotation do
  it "should deserialize json-ld annotations" do
    Cerberus::Annotations::Annotation.from_json annotation_fixture("annotation-comment-as-text-chars.json")
  end

  def annotation_fixture fixture
    File.read fixture_path("annotations/#{fixture}")
  end
end
