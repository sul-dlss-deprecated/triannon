require 'spec_helper'

describe Triannon::AnnotationsController, type: :routing do

  routes {Triannon::Engine.routes}

  context 'GET to root url' do
    it '/ routed to triannon/search#find without anno_root param' do
      expect(:get => "/").to route_to(controller: "triannon/search", action: "find")
    end
  end
  context 'GET to /annotations' do
    it '/annotations routed to triannon/search#find without anno_root param' do
      expect(:get => "/annotations").to route_to(controller: "triannon/search", action: "find")
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

  context '/search' do
    it "/annotations/:anno_root/search routed to triannon/search#find with anno_root param" do
      expect(:get => "/annotations/dms/search").to route_to(controller: "triannon/search", action: "find", anno_root: "dms")
    end
    it "/annotations/:anno_root/search?params routed to triannon/search#find with anno_root param" do
      expect(:get => "/annotations/dms/search?target=neato.url.org").to route_to(controller: "triannon/search", action: "find", anno_root: "dms", target: "neato.url.org")
      expect(:get => "/annotations/dms/search?foo=bar").to route_to(controller: "triannon/search", action: "find", anno_root: "dms", :foo => "bar")
    end
    it '/annotations routed to triannon/search#find without anno_root param' do
      expect(:get => "/").to route_to(controller: "triannon/search", action: "find")
    end
    it "/annotations/search?params routed to triannon/search#find without anno_root param" do
      expect(:get => "/annotations/search?target=neato.url.org").to route_to(controller: "triannon/search", action: "find", target: "neato.url.org")
      expect(:get => "/annotations/search?foo=bar").to route_to(controller: "triannon/search", action: "find", :foo => "bar")
    end
    it "/search?params routed to triannon/search#find without anno_root param" do
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
  end # search

end
