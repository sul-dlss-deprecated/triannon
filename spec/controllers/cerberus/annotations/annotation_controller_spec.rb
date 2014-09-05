require 'spec_helper'

describe Cerberus::Annotations::AnnotationsController, type: :controller do
  
  routes { Cerberus::Annotations::Engine.routes }

  it "should have an index" do
    get :index
  end
  
  it "should have a show" do
    get :show, id: 'annotation-comment-as-text-chars'
    expect(assigns[:annotation]).to be_kind_of Cerberus::Annotations::Annotation
  end
end
