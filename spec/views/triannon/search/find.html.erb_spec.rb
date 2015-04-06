require 'spec_helper'

RSpec.describe "triannon/search/find.html.erb", :type => :view do

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

  it "displays all the annos" do
    assign(:list_hash, Triannon::IIIFAnnoList.anno_list(anno_graphs_array))
    render
    expect(rendered).to match /http:\/\/purl.stanford.edu\/kq131cs7229/
    expect(rendered).to match /http:\/\/purl.stanford.edu\/oo111oo2222/
    expect(rendered).to match /I hate this!/
    expect(rendered).to match /I love this!/
    expect(rendered).to match /testing redirect 2/
  end

  it "contains jsonld wrapped in <pre> tag" do
    assign(:list_hash, Triannon::IIIFAnnoList.anno_list(anno_graphs_array))
    render
    # regex: \A and \Z and m are used instead of ^$ due to possible \n in data)
    expect(rendered).to match /\A<pre>\s*\{.+\}\s*<\/pre>\Z/m
  end
end
