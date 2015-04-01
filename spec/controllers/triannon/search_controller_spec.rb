require 'spec_helper'

describe Triannon::SearchController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  describe "GET find" do
    let(:anno_graphs_array) { [
      Triannon::Graph.new(RDF::Graph.new.from_jsonld('
        { "@context":"http://www.w3.org/ns/oa-context-20130208.json",
          "@graph": [
            { "@id":"_:g70337046884060",
              "@type":["dctypes:Text","cnt:ContentAsText"],
              "chars":"I hate this!"
            },
            { "@id":"http://your.triannon-server.com/annotations/d3019689-d3ff-4290-8ee3-72fec2320332",
              "@type":"oa:Annotation",
              "hasBody":"_:g70337046884060",
              "hasTarget":"http://purl.stanford.edu/kq131cs7229",
              "motivatedBy":"oa:commenting"
            }
          ]
        }')),
      Triannon::Graph.new(RDF::Graph.new.from_jsonld('
        { "@context":"http://www.w3.org/ns/oa-context-20130208.json",
          "@graph": [
            { "@id":"_:g70337056969180",
              "@type":["dctypes:Text","cnt:ContentAsText"],
              "chars":"I love this!"
            },
            { "@id":"http://your.triannon-server.com/annotations/51558876-f6df-4da4-b268-02c8bff94391",
              "@type":"oa:Annotation",
              "hasBody":"_:g70337056969180",
              "hasTarget":"http://purl.stanford.edu/kq131cs7229",
              "motivatedBy":"oa:commenting"
            }
          ]
        }')),
      Triannon::Graph.new(RDF::Graph.new.from_jsonld('
        { "@context":"http://www.w3.org/ns/oa-context-20130208.json",
          "@graph": [
            { "@id":"_:g70252904268480",
              "@type":["dctypes:Text","cnt:ContentAsText"],
              "chars":"testing redirect 2"
            },
            { "@id":"http://your.triannon-server.com/annotations/5686cffa-14c1-4aa4-8cef-bf62e9f4ab82",
              "@type":"oa:Annotation",
              "hasBody":"_:g70252904268480",
              "hasTarget":"http://purl.stanford.edu/oo111oo2222",
              "motivatedBy":"oa:commenting"
            }
          ]
        }'))
      ] }
    
    it "returns http success" do
      get :find
      expect(response).to have_http_status(:success)
    end
    it "calls solr_searcher.find" do
      params = {'targetUri' => "some.url.org", 'bodyExact' => "foo"}
      ss = subject.send(:solr_searcher)
      expect(ss).to receive(:find).with(hash_including(params))
      get :find, params
    end
    
=begin TODO: implement find action in controller
    it "returns a IIIF Annotation List" do
      ss = subject.send(:solr_searcher)
      allow(ss).to receive(:find).and_return(anno_graphs_array)
      fail "test to be implemented"
    end
    it "has each anno in solr response" do
      ss = subject.send(:solr_searcher)
      allow(ss).to receive(:find).and_return(anno_graphs_array)
      fail "test to be implemented"
    end
    it "has list size = num annos in the Solr response" do
      fail "test to be implemented"
    end
    it "returns jsonld annos in IIIF context" do
      fail "test to be implemented"
    end
    context 'response formats' do
      context 'jsonld context' do
 
      end
    end
=end
  end # GET find
  

end
