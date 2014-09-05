require 'spec_helper'

describe "listing annotations", type: :feature do
  it "should work" do
    visit '/annotations'
    expect(page).to have_content "ok"
  end
end
