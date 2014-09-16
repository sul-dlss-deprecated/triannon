require 'spec_helper'

describe Cerberus::Annotations::AnnotationsController, type: :controller do

  routes { Cerberus::Annotations::Engine.routes }

  it "should have an index" do
    get :index
  end

  it "should have a show" do
    @annotation = Cerberus::Annotations::Annotation.create(data: 'asdasdfasdfasdfasdfsdafsdfaadfasdfafasfda')

    get :show, id: @annotation.id
    expect(assigns[:annotation]).to eq @annotation
  end
end
