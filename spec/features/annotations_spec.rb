require 'spec_helper'

describe "viewing an annotation", :vcr, type: :feature do
  context 'html' do
    before(:each) do
      annotation = create_annotation('body-chars.json')
      allow(Triannon::Annotation).to receive(:find).and_return(annotation)
      visit "/annotations/#{annotation.id}.html"
    end

    it "has a page title" do
      expect(page).to have_content "Annotation"
    end

    it "has the id/url" do
      expect(page).to have_content "http://example.org/annos/annotation/body-chars.json"
    end

    context "has motivation" do
      it "single" do
        expect(page).to have_content "http://www.w3.org/ns/oa#commenting"
      end
      it "multiple" do
        anno = create_annotation('mult-motivations.json')
        allow(Triannon::Annotation).to receive(:find).with(anno.id).and_return(anno)
        visit "/annotations/#{anno.id}.html"
        expect(page).to have_content "http://www.w3.org/ns/oa#moderating"
        expect(page).to have_content "http://www.w3.org/ns/oa#tagging"
      end
    end

    it "turtle" do
      expect(page).to have_content "Turtle"
      expect(page).to have_content "a <http://www.w3.org/ns/oa#Annotation>"
    end

    it "jsonld OpenAnnotation context" do
      expect(page).to have_content "OpenAnnotation context"
      expect(page).to have_content "@context\":\"#{Triannon::JsonldContext::OA_CONTEXT_URL}\""
    end

    it "jsonld IIIF context" do
      expect(page).to have_content "IIIF context"
      expect(page).to have_content "@context\":\"#{Triannon::JsonldContext::IIIF_CONTEXT_URL}\""
    end
  end

  def create_annotation f
    Triannon::Annotation.new data: annotation_fixture(f), id: '1234'
  end

  def annotation_fixture fixture
    File.read Triannon.fixture_path("annotations/#{fixture}")
  end
end
