require 'spec_helper'

describe "integration tests for content as text", :vcr do

  it 'body is blank node with content as text' do
    body_text = "I love this!"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new data: 
    "@prefix content: <http://www.w3.org/2011/content#> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <> a openannotation:Annotation;
       openannotation:hasBody [
         a content:ContentAsText,
           dcmitype:Text;
         content:chars \"#{body_text}\"
       ];
       openannotation:hasTarget <#{target_uri}>;
       openannotation:motivatedBy openannotation:commenting .
    "
    g = write_anno.graph
    expect(g.size).to eql 7
    expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = g.query([nil, RDF::OpenAnnotation.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(g.query([body_node, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
    expect(g.query([body_node, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node, RDF::Content.chars, RDF::Literal.new(body_text)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql 7
    anno_uri_obj = RDF::URI("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri)]).size).to eql 1 
    body_solns = h.query([anno_uri_obj, RDF::OpenAnnotation.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(h.query([body_node, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
    expect(h.query([body_node, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    expect(h.query([body_node, RDF::Content.chars, RDF::Literal.new(body_text)]).size).to eql 1
  end
  
  it 'body is blank node with content as text w diff triples' do
    body_text = "I love this!"
    body_format = "text/plain"
    body_lang = "en"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new data: 
    "@prefix content: <http://www.w3.org/2011/content#> .
    @prefix dc11: <http://purl.org/dc/elements/1.1/> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <> a openannotation:Annotation;
       openannotation:hasBody [
         a content:ContentAsText,
           dcmitype:Text;
         dc11:format \"#{body_format}\";
         dc11:language \"#{body_lang}\";
         content:chars \"#{body_text}\"
       ];
       openannotation:hasTarget <#{target_uri}>;
       openannotation:motivatedBy openannotation:commenting .
    "
    g = write_anno.graph
    expect(g.size).to eql 9
    expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = g.query([nil, RDF::OpenAnnotation.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(g.query([body_node, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
    expect(g.query([body_node, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node, RDF::DC11.format, RDF::Literal.new(body_format)]).size).to eql 1
    expect(g.query([body_node, RDF::DC11.language, RDF::Literal.new(body_lang)]).size).to eql 1
    expect(g.query([body_node, RDF::Content.chars, RDF::Literal.new(body_text)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql 9
    anno_uri_obj = RDF::URI("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri)]).size).to eql 1 
    body_solns = h.query([anno_uri_obj, RDF::OpenAnnotation.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(h.query([body_node, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
    expect(h.query([body_node, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    expect(h.query([body_node, RDF::DC11.format, RDF::Literal.new(body_format)]).size).to eql 1
    expect(h.query([body_node, RDF::DC11.language, RDF::Literal.new(body_lang)]).size).to eql 1
    expect(h.query([body_node, RDF::Content.chars, RDF::Literal.new(body_text)]).size).to eql 1
  end

  it 'two bodies each as blank nodes' do
    body_text1 = "I love this!"
    body_text2 = "I hate this!"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new data: 
    "@prefix content: <http://www.w3.org/2011/content#> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <> a openannotation:Annotation;
       openannotation:hasBody [
         a content:ContentAsText,
           dcmitype:Text;
         content:chars \"#{body_text1}\"
       ],
       [
          a content:ContentAsText,
            dcmitype:Text;
          content:chars \"#{body_text2}\"
        ];
       openannotation:hasTarget <#{target_uri}>;
       openannotation:motivatedBy openannotation:commenting .
    "
    g = write_anno.graph
    expect(g.size).to eql 11
    expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    body_solns = g.query([nil, RDF::OpenAnnotation.hasBody, nil])
    expect(body_solns.size).to eql 2
    body_node1 = body_solns.first.object
    expect(g.query([body_node1, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
    expect(g.query([body_node1, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node1, RDF::Content.chars, RDF::Literal.new(body_text1)]).size).to eql 1
    body_node2 = body_solns.to_a[1].object
    expect(g.query([body_node2, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
    expect(g.query([body_node2, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    expect(g.query([body_node2, RDF::Content.chars, RDF::Literal.new(body_text2)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql 11
    anno_uri_obj = RDF::URI("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri)]).size).to eql 1 
    body_solns = h.query([anno_uri_obj, RDF::OpenAnnotation.hasBody, nil])
    expect(body_solns.size).to eql 2
    body_node1 = body_solns.first.object
    expect(h.query([body_node1, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
    expect(h.query([body_node1, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    expect(h.query([body_node1, RDF::Content.chars, RDF::Literal.new(body_text1)]).size).to eql 1
    body_node2 = body_solns.to_a[1].object
    expect(h.query([body_node2, RDF.type, RDF::Content.ContentAsText]).size).to eql 1
    expect(h.query([body_node2, RDF.type, RDF::DCMIType.Text]).size).to eql 1
    expect(h.query([body_node2, RDF::Content.chars, RDF::Literal.new(body_text2)]).size).to eql 1
  end
end