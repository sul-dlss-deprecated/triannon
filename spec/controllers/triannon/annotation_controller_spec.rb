require 'spec_helper'

vcr_options = { :cassette_name => "features_annotations_index" }
describe Triannon::AnnotationsController, type: :controller, :vcr => vcr_options do

  routes { Triannon::Engine.routes }

  it "should have an index" do
    get :index
  end

  it "should have a show" do
    @annotation = Triannon::Annotation.create(data: 'asdasdfasdfasdfasdfsdafsdfaadfasdfafasfda')

    get :show, id: @annotation.id
    expect(assigns[:annotation]).to eq @annotation
  end
end
