require 'spec_helper'

describe "creating an annotation", :vcr, type: :feature do
  let(:root_container) { 'new_anno_feature' }
  context 'html' do
    before(:each) do
      visit "/annotations/#{root_container}/new"
    end

    it "has a page title" do
      expect(page).to have_title "Triannon"
    end

    it "has text box for anno" do
      expect(page).to have_content "Annotation (as json-ld or turtle)"
    end

    it 'has submit button' do
      expect(page).to have_button "Create Annotation"
    end

    it 'redirects to show after anno created' do
      vcr_cassette_name = "creating_an_annotation/creating_root_container"
      create_root_container(root_container, vcr_cassette_name)
      page.fill_in 'annotation_data', with: Triannon.annotation_fixture('body-chars-no-id.json')
      click_on('Create Annotation')
      expect(page).to have_content "I love this!"
      vcr_cassette_name = "creating_an_annotation/deleting_root_container"
      ldp_testing_container_urls = ["#{spec_ldp_url}/#{spec_uber_cont}/#{root_container}"]
      delete_test_objects(ldp_testing_container_urls, [], root_container, vcr_cassette_name)
    end
  end

end
