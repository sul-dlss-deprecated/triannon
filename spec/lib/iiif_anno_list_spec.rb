require 'spec_helper'

describe Triannon::IIIFAnnoList, :vcr do
  
  context '.anno_list' do
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
    let(:anno_list) { Triannon::IIIFAnnoList.anno_list(anno_graphs_array) }
    
    it "returns a Hash" do
      expect(anno_list).to be_a Hash
    end
    it "@context is IIIF" do
      expect(anno_list["@context"]).to eq Triannon::JsonldContext::IIIF_CONTEXT_URL
    end
    it "@type is sc:AnnotationList" do
      expect(anno_list["@type"]).to eq "sc:AnnotationList"
    end
    it "no @id" do
      expect(anno_list["@id"]).to eq nil
    end
    context 'within' do
      let(:within) { anno_list["within"] }
      it "type sc:Layer" do
        expect(within["@type"]).to eq "sc:Layer"
      end
      it "total = num annos in anno_graphs_array" do
        expect(within["total"]).to eq anno_graphs_array.size
      end
    end
    context 'resources' do
      it "is an Array of size (num annos in anno_graphs_array)" do
        expect(anno_list["resources"]).to be_an Array
        expect(anno_list["resources"].size).to eq anno_graphs_array.size
      end
      it "each element is a Hash representing IIIF jsonld of anno" do
        anno_list["resources"].each_index { |i|
          element = anno_list["resources"][i]
          expect(element).to be_a Hash
          g = element["@graph"]
          anno_node_hash = g.find { |node| node["@type"] == "oa:Annotation"}
          expect(anno_node_hash["@id"]).to eq anno_graphs_array[i].id_as_url.to_s
          # "on" is IIIF, not OA
          expect(anno_node_hash["on"]).to eq anno_graphs_array[i].predicate_urls(RDF::OpenAnnotation.hasTarget).first
        }
      end
      it "elements do not have @context (it's redundant)" do
        anno_list["resources"].each_index { |i|
          element = anno_list["resources"][i]
          expect(element.key?("@context")).to be false
        }
      end
      it "returns nil if it receives nil" do
        expect(Triannon::IIIFAnnoList.anno_list(nil)).to eq nil
      end
      it "returns empty list if it receives empty Array" do
        empty_list = Triannon::IIIFAnnoList.anno_list []
        expect(empty_list).to be_a Hash
        expect(empty_list["@context"]).to eq Triannon::JsonldContext::IIIF_CONTEXT_URL
        expect(empty_list["@type"]).to eq "sc:AnnotationList"
        expect(empty_list["@id"]).to eq nil
        within = empty_list["within"]
        expect(within["@type"]).to eq "sc:Layer"
        expect(within["total"]).to eq 0
        expect(empty_list["resources"]).to be_an Array
        expect(empty_list["resources"].size).to eq 0
      end
    end # resources
  end # anno_list

end