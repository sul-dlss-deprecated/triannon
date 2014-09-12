require 'spec_helper'

describe "viewing an annotation", type: :feature do

  it "has a title" do
    annotation = create_annotation('annotation-comment-as-text-chars.json')
    visit "/annotations/annotations/#{annotation.id}"
    expect(page).to have_content "Annotation"
  end

  it "has the annotation content" do
    annotation = create_annotation('annotation-comment-as-text-chars.json')
    visit "/annotations/annotations/#{annotation.id}"

    expect(page).to have_content "I love this!"
  end

  def create_annotation f
    Cerberus::Annotations::Annotation.create data: annotation_fixture(f)
  end

  def annotation_fixture fixture
    File.read Cerberus::Annotations.fixture_path("annotations/#{fixture}")
  end
end
