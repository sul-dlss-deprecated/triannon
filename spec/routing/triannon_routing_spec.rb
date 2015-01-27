require 'spec_helper'

describe Triannon::AnnotationsController, type: :routing do

  routes {Triannon::Engine.routes}

  context 'http GET with id' do
    it '/annotation/:id (GET) routes to #show in annotations controller' do
      expect(:get => "/annotations/666").to route_to(:controller => "triannon/annotations", :action => "show", :id => "666")
    end

    context 'jsonld_context' do
      it '/annotation/iiif/:id (GET) routes to #show with jsonld_context of iiif' do
        expect(:get => "/annotations/iiif/666").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "iiif", :id => "666")
      end
      it '/annotation/oa/:id (GET) routes to #show with jsonld_context of oa' do
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
      it '/annotations/666?jsonld_context=iiif routes to #show with jsonld_context of iiif' do
        expect(:get => "/annotations/666?jsonld_context=iiif").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "iiif", :id => "666")
      end
      it '/annotations/666?jsonld_context=IIIF routes to #show with jsonld_context of IIIF' do
        expect(:get => "/annotations/666?jsonld_context=IIIF").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "IIIF", :id => "666")
      end
      it '/annotations/666?jsonld_context=oa routes to #show with jsonld_context of oa' do
        expect(:get => "/annotations/666?jsonld_context=oa").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "oa", :id => "666")
      end
      it '/annotations/666?jsonld_context=OA routes to #show with jsonld_context of OA' do
        expect(:get => "/annotations/666?jsonld_context=OA").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "OA", :id => "666")
      end
      it '/annotations/666?jsonld_context=foo routes to #show with jsonld_context of oa' do
        expect(:get => "/annotations/666?jsonld_context=foo").to route_to(:controller => "triannon/annotations", :action => "show", :jsonld_context => "foo", :id => "666")
      end
    end
  end

  context 'http GET without id' do
    it '(plain) routes to #index in annotations controller' do
      expect(:get => "/annotations").to route_to(:controller => "triannon/annotations", :action => "index")
    end
    it 'iiif should not be available' do
      expect(:get => "/annotations/iiif").to_not be_routable
    end
    it 'oa should not be available' do
      expect(:get => "/annotations/oa").to_not be_routable
    end
  end
  
  context 'http GET to root without id' do
    it '(plain) routes to #index in annotations controller' do
      expect(:get => "/").to route_to(:controller => "triannon/annotations", :action => "index")
    end
    it 'iiif should not be available' do
      expect(:get => "/iiif").to_not be_routable
    end
    it 'oa should not be available' do
      expect(:get => "/oa").to_not be_routable
    end
  end

  context 'http GET with new' do
    it '(plain) routes to #new in annotations controller' do
      expect(:get => "/annotations/new").to route_to(:controller => "triannon/annotations", :action => "new")
    end
    it 'iiif should not be available' do
      expect(:get => "/annotations/iiif/new").to_not be_routable
    end
    it 'oa should not be available' do
      expect(:get => "/annotations/oa/new").to_not be_routable
    end
  end
  
  context 'http POST' do
    it '(plain) routes to #create in annotations controller' do
      expect(:post => "/annotations").to route_to(:controller => "triannon/annotations", :action => "create")
    end
    it 'iiif should not be available' do
      expect(:post => "/annotations/iiif").to_not be_routable
    end
    it 'oa should not be available' do
      expect(:post => "/annotations/oa").to_not be_routable
    end
  end

  context 'http DELETE with id' do
    it '(plain) routed to #destroy in annotations controller' do
      expect(:delete => "/annotations/666").to route_to(:controller => "triannon/annotations", :action => "destroy", :id => "666")
    end
    it 'iiif should not be available' do
      expect(:delete => "/annotations/iiif/666").to_not be_routable
    end
    it 'oa should not be available' do
      expect(:delete => "/annotations/oa/666").to_not be_routable
    end
  end

  context 'http PUT' do
    it '(plain) should not be available' do
      expect(:put => "/annotations/666").to_not be_routable
    end
#    it '(plain) routes to #update in annotations controller' do
#      expect(:put => "/annotations/666").to route_to(:controller => "triannon/annotations", :action => "update", :id => "666")
#    end
    it 'iiif should not be available' do
      expect(:put => "/annotations/iiif/666").to_not be_routable
    end
    it 'oa should not be available' do
      expect(:put => "/annotations/oa/666").to_not be_routable
    end
  end
  
  context 'http PATCH' do
    it '(plain) should not be available' do
      expect(:patch => "/annotations/666").to_not be_routable
    end
    it 'iiif should not be available' do
      expect(:patch => "/annotations/iiif/666").to_not be_routable
    end
    it 'oa should not be available' do
      expect(:patch => "/annotations/oa/666").to_not be_routable
    end
  end

end