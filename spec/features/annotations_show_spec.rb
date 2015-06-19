require 'spec_helper'

describe "viewing an annotation", :vcr, type: :feature do
  let(:root_container) { 'view_anno_feature' }
  context 'html' do
    before(:each) do
      annotation = create_annotation('body-chars.json')
      allow(Triannon::Annotation).to receive(:find).and_return(annotation)
      visit "/annotations/#{root_container}/#{annotation.id}.html"
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
        allow(Triannon::Annotation).to receive(:find).with(root_container, anno.id).and_return(anno)
        visit "/annotations/#{root_container}/#{anno.id}.html"
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
      expect(page).to have_content "@context\":\"#{OA::Graph::OA_DATED_CONTEXT_URL}\""
    end

    it "jsonld IIIF context" do
      expect(page).to have_content "IIIF context"
      expect(page).to have_content "@context\":\"#{OA::Graph::IIIF_CONTEXT_URL}\""
    end
  end

  def create_annotation f
    Triannon::Annotation.new(root_container: root_container, data: Triannon.annotation_fixture(f), id: '1234')
  end

end
