require 'spec_helper'

describe "integration tests for no body", :vcr do

  it 'comment (no tags)' do
  	body_text = "Yet another line of unreadable text."
  	body_mime_type = "text/html"
    source_url = "http://manifests.ydc2.yale.edu/canvas/3a38190c-49a2-4e24-8ac8-b886087e63da"
    frag_value = "xywh=2244,2086,1176,188"
    catch_value = "xywh=-872,0,5406,4489"
    write_anno = Triannon::Annotation.new data: '{
			   "@context":"http://iiif.io/api/presentation/2/context.json",
			   "@type":"oa:Annotation",
			   "motivation":[  
			      "oa:commenting"
			   ],
			   "resource":[  
			      {  
			         "@type":"dctypes:Text",
			         "format":"text/html",
			         "chars":"Yet another line of unreadable text."
			      }
			   ],
			   "on":{  
			      "@type":"oa:SpecificResource",
			      "source":"http://manifests.ydc2.yale.edu/canvas/3a38190c-49a2-4e24-8ac8-b886087e63da",
			      "selector":{  
			         "@type":"oa:FragmentSelector",
			         "value":"xywh=2244,2086,1176,188"
			      },
			      "scope":{  
			         "@context":"http://www.harvard.edu/catch/oa.json",
			         "@type":"catch:Viewport",
			         "value":"xywh=-872,0,5406,4489"
			      }
			   }
			}'
    g = write_anno.graph
    expect(g.size).to eql 10
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    
    body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(g.query([body_node, RDF.type, RDF::Vocab::CNT.ContentAsText]).size).to eql 1
    expect(g.query([body_node, RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node, RDF::Vocab::DC.Format, body_mime_type]).size).to eql 1
    expect(g.query([body_node, RDF::Vocab::CNT.chars, RDF::Literal.new(body_text)]).size).to eql 1

    target_solns = g.query([nil, RDF::Vocab::OA.hasTarget, nil])
    expect(target_solns.size).to eql 1
    target_blank_node = target_solns.first.object
    expect(g.query([target_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(g.query([target_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1

    selector_solns = g.query([target_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = g.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 3
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.FragmentSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF.value, frag_value]

    scope_solns = g.query([target_blank_node, RDF::Vocab::OA.hasScope, nil])
    expect(scope_solns.size).to eql 1
    scope_blank_node = scope_solns.first.object
    scope_contents_solns = g.query([scope_blank_node, nil, nil])
    expect(scope_contents_solns.size).to eql 3
    expect(scope_contents_solns.to include [scope_blank_node, RDF.value, catch_value])

    expect(g.query([nil, RDF::Vocab::OA.hasBody, nil]).size).to eql 1


    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
    target_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, nil])
    expect(target_solns.size).to eql 1
    target_blank_node = target_solns.first.object
    expect(h.query([target_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(h.query([target_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = h.query([target_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = h.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 3
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.FragmentSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF.value, frag_value]
  end # comment no tags

end
