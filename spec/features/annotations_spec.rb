require 'spec_helper'

describe "viewing an annotation", type: :feature do
  it "has a title" do
    visit '/annotations/annotations/annotation-comment-as-text-chars'
    expect(page).to have_content "Annotation"
  end  
  
  it "has the annotation content" do
    visit '/annotations/annotations/annotation-comment-as-text-chars'
    expect(page).to have_content "I love this!"
  end
end
