require 'spec_helper'

describe Cerberus::Annotations::AnnotationsController, type: :controller do
  
  routes { Cerberus::Annotations::Engine.routes }

  it "should have an index" do
    get :index
  end
end
