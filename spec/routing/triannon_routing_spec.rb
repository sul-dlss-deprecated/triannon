require 'spec_helper'

describe Triannon::AnnotationsController, type: :routing do

  routes {Triannon::Engine.routes}

  context 'GET to root url' do
    it '/ routed to triannon/search#find without anno_root param' do
      expect(:get => "/").to route_to(controller: "triannon/search", action: "find")
    end
  end

  context "GET" do
    context "#show" do
      it '/annotations/:anno_root/:id (GET) routed to triannon/annotations#show with params' do
        expect(:get => "/annotations/foo/666").to route_to(controller: "triannon/annotations", action: "show", anno_root: "foo", id: "666")
      end
      it '/:anno_root/:id (GET) routed to triannon/annotations#show with params' do
        expect(:get => "/foo/666").to route_to(controller: "triannon/annotations", action: "show", anno_root: "foo", id: "666")
      end
      context "forbidden anno_root values" do
        it '/search/:id is not routable' do
          expect(:get => "/search/666").not_to be_routable
        end
        it '/new/:id is not routable' do
          expect(:get => "/new/666").not_to be_routable
        end
        it '/annotations/:id routed to triannon/annotations#index with anno_root param' do
          expect(:get => "/annotations/666").to route_to(controller: "triannon/annotations", action: "index", anno_root: "666")
        end
      end
    end
    context "#index" do
      it '/annotations/:anno_root routed to triannon/annotations#index with anno_root param' do
        expect(:get => "/annotations/foo").to route_to(controller: "triannon/annotations", action: "index", anno_root: "foo")
      end
      it '/:anno_root routed to triannon/annotations#index with anno_root param' do
        expect(:get => "/foo").to route_to(controller: "triannon/annotations", action: "index", anno_root: "foo")
      end
      context "forbidden anno_root values" do
        it '/new is not routable' do
          expect(:get => "/new").not_to be_routable
        end
        # /annotations goes to search#find - tested elsewhere
        # /search goes to search#find - tested elsewhere
      end
    end
    context "new" do
      it '/annotations/:anno_root/new routed to triannon/annotations#new with anno_root param' do
        expect(:get => "/annotations/foo/new").to route_to(controller: "triannon/annotations", action: "new", anno_root: "foo")
      end
      it '/:anno_root/new routed to triannon/annotations#new with anno_root param' do
        expect(:get => "/foo/new").to route_to(controller: "triannon/annotations", action: "new", anno_root: "foo")
      end
      context "forbidden anno_root values" do
        it '/search/new is not routable' do
          expect(:get => "/search/new").not_to be_routable
        end
        it 'new/new is not routable' do
          expect(:get => "/new/new").not_to be_routable
        end
        it '/annotations/new is not routable' do
          expect(:get => "/annotations/new").not_to be_routable
        end
      end
      it '/new is not routable' do
        expect(:get => "/new").not_to be_routable
      end
    end
  end # GET

  context 'POST' do
    it '/annotations/:anno_root routed to triannon/annotations#create with anno_root param' do
      expect(:post => "/annotations/foo").to route_to(controller: "triannon/annotations", action: "create", anno_root: "foo")
    end
    it '/:anno_root routed to triannon/annotations#create with anno_root param' do
      expect(:post => "/annotations/foo").to route_to(controller: "triannon/annotations", action: "create", anno_root: "foo")
    end
    context "forbidden anno_root values" do
      it '/annotations is not routable' do
        expect(:post => "/annotations").not_to be_routable
      end
      it '/search is not routable' do
        expect(:post => "/search").not_to be_routable
      end
      it '/new is not routable' do
        expect(:post => "/new").not_to be_routable
      end
    end
  end

  context 'DELETE' do
    it '/annotations/:anno_root/:id routed to triannon/annotations#destroy' do
      expect(:delete => "/annotations/foo/666").to route_to(controller: "triannon/annotations", action: "destroy", anno_root: "foo", id: "666")
    end
    it '/:anno_root/:id routed to triannon/annotations#destroy' do
      expect(:delete => "/foo/666").to route_to(controller: "triannon/annotations", action: "destroy", anno_root: "foo", id: "666")
    end
    context "forbidden anno_root values" do
      it '/annotations/:id is not routable' do
        expect(:delete => "/annotations/666").not_to be_routable
      end
      it '/search/:id is not routable' do
        expect(:delete => "/search/666").not_to be_routable
      end
      it '/new/:id is not routable' do
        expect(:delete => "/new/666").not_to be_routable
      end
    end
  end

  context 'http PUT' do
    it '/annotations/:anno_root/:id is not YET routable' do
      expect(:put => "/annotations/foo/666").not_to be_routable
    end
    #it '/annotations/:anno_root/:id routed to triannon/search#update with params' do
    #  expect(:put => "/annotations/foo/666").to route_to(controller: "triannon/annotations", action: "update", anno_root: "foo", id: "666")
    #end
    it '/:anno_root/:id is not YET routable' do
      expect(:put => "/foo/666").not_to be_routable
    end
    #it '/:anno_root/:id routed to triannon/search#update with params' do
    #  expect(:put => "/foo/666").to route_to(controller: "triannon/annotations", action: "update", anno_root: "foo", id: "666")
    #end
    context "forbidden anno_root values" do
      it '/annotations/:id is not routable' do
        expect(:put => "/annotations/666").not_to be_routable
      end
      it '/search/:id is not routable' do
        expect(:put => "/search/666").not_to be_routable
      end
      it '/new/:id is not routable' do
        expect(:put => "/new/666").not_to be_routable
      end
    end
  end

  context 'http PATCH' do
    it '/annotations/:anno_root/:id is not routable' do
      expect(:patch => "/annotations/foo/666").not_to be_routable
    end
    it '/:anno_root/:id is not routable' do
      expect(:patch => "/foo/666").not_to be_routable
    end
    context "forbidden anno_root values" do
      it '/annotations/:id is not routable' do
        expect(:patch => "/annotations/666").not_to be_routable
      end
      it '/search/:id is not routable' do
        expect(:patch => "/search/666").not_to be_routable
      end
      it '/new/:id is not routable' do
        expect(:patch => "/new/666").not_to be_routable
      end
    end
  end

=begin
  context '/search' do
    it '/annotations routed to triannon/search#find without anno_root param' do
      expect(:get => "/").to route_to(controller: "triannon/search", action: "find", anno_root: nil)
    end
    it "/annotations/:anno_root/search?params (GET) routed to triannon/search#find with params" do
      expect(:get => "/annotations/dms/search?target=neato.url.org").to route_to(controller: "triannon/search", action: "find", anno_root: "dms", target: "neato.url.org")
      expect(:get => "/annotations/dms/search?foo=bar").to route_to(controller: "triannon/search", action: "find", anno_root: "dms", :foo => "bar")
      expect(:get => "/annotations/dms/search").to route_to(controller: "triannon/search", action: "find", anno_root: "dms")
    end
    it "/annotations/search?params (GET) routed to triannon/search#find without anno_root param" do
      expect(:get => "/annotations/search?target=neato.url.org").to route_to(controller: "triannon/search", action: "find", target: "neato.url.org")
      expect(:get => "/annotations/search?foo=bar").to route_to(controller: "triannon/search", action: "find", :foo => "bar")
    end
    it "/search?params (GET) routed to triannon/search#find without anno_root param" do
      expect(:get => "/search?target=neato.url.org").to route_to(controller: "triannon/search", action: "find", target: "neato.url.org")
      expect(:get => "/search?foo=bar").to route_to(controller: "triannon/search", action: "find", :foo => "bar")
    end
    it "does not take an id" do
      expect(:get => "/annotations/dms/search/666").not_to be_routable
      expect(:get => "/annotations/search/666").not_to be_routable
      expect(:get => "/search/666").not_to be_routable
    end
    it "http POST should not be available" do
      expect(:post => "/annotations/dms/search").not_to be_routable
      expect(:post => "/annotations/search").not_to be_routable
      expect(:post => "/search").not_to be_routable
    end
    it "http DELETE should not be available" do
      expect(:delete => "/annotations/dms/search").not_to be_routable
      expect(:delete => "/annotations/search").not_to be_routable
      expect(:delete => "/search").not_to be_routable
      expect(:delete => "/annotations/search/666").not_to be_routable
    end
    it "http PUT should not be available" do
      expect(:put => "/annotations/dms/search").not_to be_routable
      expect(:put => "/annotations/search").not_to be_routable
      expect(:put => "/search").not_to be_routable
      expect(:put => "/annotations/search/666").not_to be_routable
    end
    it "http PATCH should not be available" do
      expect(:patch => "/annotations/dms/search").not_to be_routable
      expect(:patch => "/annotations/search").not_to be_routable
      expect(:patch => "/search").not_to be_routable
      expect(:patch => "/annotations/search/666").not_to be_routable
    end
  end

=end

# ---   before multiple root anno containers ---

=begin

  context 'http GET with id' do
    it '/annotation/:id (GET) routes to #show in annotations controller' do
      expect(:get => "/annotations/666").to route_to(controller: "triannon/annotations", action: "show", id: "666")
    end

    context 'jsonld_context' do
      it '/annotation/iiif/:id (GET) routes to #show with jsonld_context of iiif' do
        expect(:get => "/annotations/iiif/666").to route_to(controller: "triannon/annotations", action: "show", :jsonld_context => "iiif", id: "666")
      end
      it '/annotation/oa/:id (GET) routes to #show with jsonld_context of oa' do
        expect(:get => "/annotations/oa/666").to route_to(controller: "triannon/annotations", action: "show", :jsonld_context => "oa", id: "666")
      end
      it '/annotation/IIIF/:id (GET) should not be available' do
        expect(:get => "/annotations/IIIF/666").not_to be_routable
      end
      it '/annotation/OA/:id (GET) should not be available' do
        expect(:get => "/annotations/OA/666").not_to be_routable
      end
      it '/annotation/search/:id (GET) should not be available' do
        expect(:get => "/annotations/search/666").not_to be_routable
      end
      it '/annotation/foo/:id (GET) should not be available' do
        expect(:get => "/annotations/foo/666").not_to be_routable
      end
      it '/annotations/666?jsonld_context=iiif routes to #show with jsonld_context of iiif' do
        expect(:get => "/annotations/666?jsonld_context=iiif").to route_to(controller: "triannon/annotations", action: "show", :jsonld_context => "iiif", id: "666")
      end
      it '/annotations/666?jsonld_context=IIIF routes to #show with jsonld_context of IIIF' do
        expect(:get => "/annotations/666?jsonld_context=IIIF").to route_to(controller: "triannon/annotations", action: "show", :jsonld_context => "IIIF", id: "666")
      end
      it '/annotations/666?jsonld_context=oa routes to #show with jsonld_context of oa' do
        expect(:get => "/annotations/666?jsonld_context=oa").to route_to(controller: "triannon/annotations", action: "show", :jsonld_context => "oa", id: "666")
      end
      it '/annotations/666?jsonld_context=OA routes to #show with jsonld_context of OA' do
        expect(:get => "/annotations/666?jsonld_context=OA").to route_to(controller: "triannon/annotations", action: "show", :jsonld_context => "OA", id: "666")
      end
      it '/annotations/666?jsonld_context=foo routes to #show with jsonld_context of oa' do
        expect(:get => "/annotations/666?jsonld_context=foo").to route_to(controller: "triannon/annotations", action: "show", :jsonld_context => "foo", id: "666")
      end
    end
  end

  context 'http GET without id' do
    it '(plain) routes to #index in annotations controller' do
      expect(:get => "/annotations").to route_to(controller: "triannon/annotations", action: "index")
    end
    it 'iiif should not be available' do
      expect(:get => "/annotations/iiif").not_to be_routable
    end
    it 'oa should not be available' do
      expect(:get => "/annotations/oa").not_to be_routable
    end
  end

  context 'http GET to root without id' do
    it '(plain) routes to #find in search controller' do
      expect(:get => "/").to route_to(controller: "triannon/search", action: "find")
    end
    it 'iiif should not be available' do
      expect(:get => "/iiif").not_to be_routable
    end
    it 'oa should not be available' do
      expect(:get => "/oa").not_to be_routable
    end
  end

  context 'http GET with new' do
    it '(plain) routes to #new in annotations controller' do
      expect(:get => "/annotations/new").to route_to(controller: "triannon/annotations", action: "new")
    end
    it 'iiif should not be available' do
      expect(:get => "/annotations/iiif/new").not_to be_routable
    end
    it 'oa should not be available' do
      expect(:get => "/annotations/oa/new").not_to be_routable
    end
    it 'search should not be available' do
      expect(:get => "/annotations/search/new").not_to be_routable
    end
  end

  context 'http POST' do
    it '(plain) routes to #create in annotations controller' do
      expect(:post => "/annotations").to route_to(controller: "triannon/annotations", action: "create")
    end
    it 'iiif should not be available' do
      expect(:post => "/annotations/iiif").not_to be_routable
    end
    it 'oa should not be available' do
      expect(:post => "/annotations/oa").not_to be_routable
    end
  end

  context 'http DELETE with id' do
    it '(plain) routed to #destroy in annotations controller' do
      expect(:delete => "/annotations/666").to route_to(controller: "triannon/annotations", action: "destroy", id: "666")
    end
    it 'iiif should not be available' do
      expect(:delete => "/annotations/iiif/666").not_to be_routable
    end
    it 'oa should not be available' do
      expect(:delete => "/annotations/oa/666").not_to be_routable
    end
  end

  context 'http PUT' do
    it '(plain) should not be available' do
      expect(:put => "/annotations/666").not_to be_routable
    end
#    it '(plain) routes to #update in annotations controller' do
#      expect(:put => "/annotations/666").to route_to(controller: "triannon/annotations", action: "update", id: "666")
#    end
    it 'iiif should not be available' do
      expect(:put => "/annotations/iiif/666").not_to be_routable
    end
    it 'oa should not be available' do
      expect(:put => "/annotations/oa/666").not_to be_routable
    end
  end

  context 'http PATCH' do
    it '(plain) should not be available' do
      expect(:patch => "/annotations/666").not_to be_routable
    end
    it 'iiif should not be available' do
      expect(:patch => "/annotations/iiif/666").not_to be_routable
    end
    it 'oa should not be available' do
      expect(:patch => "/annotations/oa/666").not_to be_routable
    end
  end

  context '/search' do
    it "/annotations/search?params (GET) routes to #find in search controller with params" do
      expect(:get => "/annotations/search?target=neato.url.org").to route_to(controller: "triannon/search", action: "find", target: "neato.url.org")
      expect(:get => "/annotations/search?foo=bar").to route_to(controller: "triannon/search", action: "find", :foo => "bar")
      expect(:get => "/annotations/search").to route_to(controller: "triannon/search", action: "find")
    end
    it "/search?params (GET) routes to #find in search controller with params" do
      expect(:get => "/search?target=neato.url.org").to route_to(controller: "triannon/search", action: "find", target: "neato.url.org")
      expect(:get => "/search?foo=bar").to route_to(controller: "triannon/search", action: "find", :foo => "bar")
    end
    it "does not take an id" do
      expect(:get => "/annotations/search/666").not_to be_routable
      expect(:get => "/search/666").not_to be_routable
    end
    it "http POST should not be available" do
      expect(:post => "/annotations/search").not_to be_routable
      expect(:post => "/search").not_to be_routable
    end
    it "http DELETE should not be available" do
      expect(:delete => "/annotations/search").not_to be_routable
      expect(:delete => "/search").not_to be_routable
      expect(:delete => "/annotations/search/666").not_to be_routable
    end
    it "http PUT should not be available" do
      expect(:put => "/annotations/search").not_to be_routable
      expect(:put => "/search").not_to be_routable
      expect(:put => "/annotations/search/666").not_to be_routable
    end
    it "http PATCH should not be available" do
      expect(:patch => "/annotations/search").not_to be_routable
      expect(:patch => "/search").not_to be_routable
      expect(:patch => "/annotations/search/666").not_to be_routable
    end
  end

=end

end
