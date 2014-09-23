require 'spec_helper'

describe Triannon::AnnotationsController, type: :controller do

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
