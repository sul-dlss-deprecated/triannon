require 'spec_helper'

describe Triannon::AnnotationsController, type: :routing do

  routes {Triannon::Engine.routes}

  describe 'jsonld context' do
    context 'show action' do
      it 'routes /annotation/iiif/:id (GET) to #show with jsonld_context of iiif in annotations controller' do
        expect(:get => "/annotations/iiif/666").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "iiif", :id => "666")
      end
      it 'routes /annotation/oa/:id (GET) to #show with jsonld_context of oa in annotations controller' do
        expect(:get => "/annotations/oa/666").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "oa", :id => "666")
      end
      it '/annotation/foo/:id (GET) should not be available' do
        expect(:get => "/annotations/foo/666").to_not be_routable
      end
      it 'routes /annotation/:id (GET) to #show in annotations controller' do
        expect(:get => "/annotations/666").to route_to(:controller => "triannon/annotations", :action => "show", :id => "666")
      end    
    end
    
    context 'create action' do
      it 'create iiif should not be available' do
        expect(:post => "/annotations/iiif").to_not be_routable
      end
      it 'create oa should not be available' do
        expect(:post => "/annotations/oa").to_not be_routable
      end
      it 'create (plain) should be routed' do
        expect(:post => "/annotations").to route_to(:controller => "triannon/annotations", :action => "create")
      end
    end
    
    context 'destroy action' do
      it 'destroy iiif should not be available' do
        expect(:delete => "/annotations/iiif/666").to_not be_routable
      end
      it 'destroy oa should not be available' do
        expect(:delete => "/annotations/oa/666").to_not be_routable
      end
      it 'destroy (plain) should be routed' do
        expect(:delete => "/annotations/666").to route_to(:controller => "triannon/annotations", :action => "destroy", :id => "666")
      end
    end
    
    context 'index action' do
      it 'index iiif should not be available' do
        expect(:get => "/annotations/iiif").to_not be_routable      
      end
      it 'index oa should not be available' do
        expect(:get => "/annotations/oa").to_not be_routable      
      end
      it 'index (plain) should be routed' do
        expect(:get => "/annotations").to route_to(:controller => "triannon/annotations", :action => "index")  
      end
      it 'iiif should not be available' do
        expect(:get => "/iiif").to_not be_routable      
      end
      it 'oa should not be available' do
        expect(:get => "/oa").to_not be_routable      
      end
      it '/ should be routed' do
        expect(:get => "/").to route_to(:controller => "triannon/annotations", :action => "index")  
      end
    end
    
  end
  
end