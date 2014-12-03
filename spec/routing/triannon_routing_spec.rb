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
      it '/annotation/IIIF/:id (GET) should not be available' do
        expect(:get => "/annotations/IIIF/666").to_not be_routable
      end
      it '/annotation/OA/:id (GET) should not be available' do
        expect(:get => "/annotations/OA/666").to_not be_routable
      end
      it '/annotation/foo/:id (GET) should not be available' do
        expect(:get => "/annotations/foo/666").to_not be_routable
      end
      it 'routes /annotation/:id (GET) to #show in annotations controller' do
        expect(:get => "/annotations/666").to route_to(:controller => "triannon/annotations", :action => "show", :id => "666")
      end
      it 'routes /annotations/666?jsonld_context=iiif to #show with jsonld_context of iiif in annotations controller' do
        expect(:get => "/annotations/666?jsonld_context=iiif").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "iiif", :id => "666")
      end
      it 'routes /annotations/666?jsonld_context=IIIF to #show with jsonld_context of IIIF in annotations controller' do
        expect(:get => "/annotations/666?jsonld_context=IIIF").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "IIIF", :id => "666")
      end
      it 'routes /annotations/666?jsonld_context=oa to #show with jsonld_context of oa in annotations controller' do
        expect(:get => "/annotations/666?jsonld_context=oa").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "oa", :id => "666")
      end
      it 'routes /annotations/666?jsonld_context=OA to #show with jsonld_context of OA in annotations controller' do
        expect(:get => "/annotations/666?jsonld_context=OA").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "OA", :id => "666")
      end
      it 'routes /annotations/666?jsonld_context=foo to #show with jsonld_context of oa in annotations controller' do
        expect(:get => "/annotations/666?jsonld_context=foo").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "foo", :id => "666")
      end
    end
    
    context 'new action' do
      it 'new iiif should not be available' do
        expect(:get => "/annotations/iiif/new").to_not be_routable
      end
      it 'new oa should not be available' do
        expect(:get => "/annotations/oa/new").to_not be_routable
      end
      it 'new (plain) should be properly routed' do
        expect(:get => "/annotations/new").to route_to(:controller => "triannon/annotations", :action => "new")
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