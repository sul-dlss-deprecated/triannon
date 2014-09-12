require 'spec_helper'

describe "listing annotations", type: :feature do
  it "should work" do
    visit '/'
    expect(page).to have_link "New Annotation"
  end
end
