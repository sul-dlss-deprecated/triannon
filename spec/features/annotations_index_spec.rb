require 'spec_helper'

describe "listing annotations", type: :feature do
  it "should work" do
    visit '/annotations'
    expect(page).to have_link "annotation-comment-as-text-chars"
  end
end
