require 'spec_helper'

describe "viewing an annotation", type: :feature do

  it "has a title" do
    annotation = create_annotation('textbody.json')
    visit "/annotations/annotations/#{annotation.id}"
    expect(page).to have_content "Annotation"
  end
  
  it "has the id/url" do
    annotation = create_annotation('textbody.json')
    visit "/annotations/annotations/#{annotation.id}"
    expect(page).to have_content "http://example.org/annos/annotation/0.json"
  end

  it "has the type" do
    annotation = create_annotation('textbody.json')
    visit "/annotations/annotations/#{annotation.id}"
    expect(page).to have_content "http://www.w3.org/ns/oa#Annotation"
  end

  it "has the target url" do
    annotation = create_annotation('textbody.json')
    visit "/annotations/annotations/#{annotation.id}"
    expect(page).to have_content "http://purl.stanford.edu/kq131cs7229"
  end

  it "has the body when it's blank node with text" do
    annotation = create_annotation('textbody.json')
    visit "/annotations/annotations/#{annotation.id}"
    expect(page).to have_content "I love this!"
  end

  it "has the motivation" do
    annotation = create_annotation('textbody.json')
    visit "/annotations/annotations/#{annotation.id}"
    expect(page).to have_content "http://www.w3.org/ns/oa#commenting"
  end

  def create_annotation f
    Cerberus::Annotations::Annotation.create data: annotation_fixture(f)
  end

  def annotation_fixture fixture
    File.read Cerberus::Annotations.fixture_path("annotations/#{fixture}")
  end
end
