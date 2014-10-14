require 'spec_helper'

vcr_options = { :cassette_name => "features_annotations_index" }
describe "listing annotations", type: :feature, :vcr => vcr_options do
  context 'html' do
    it "should have New Annotation link" do
      skip 'Need Annotations.all method'
      visit '/'
      expect(page).to have_link "New Annotation"
    end
  end
end
