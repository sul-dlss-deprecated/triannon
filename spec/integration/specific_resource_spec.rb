require 'spec_helper'

describe "integration tests for SpecificResource", :vcr do
  it "target is FragmentSelector" do
    body_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    conforms_to_url = "http://www.w3.org/TR/media-frags/"
    frag_value = "xywh=0,0,200,200"
    write_anno = Triannon::Annotation.new data: "
    @prefix dc: <http://purl.org/dc/terms/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

     [
        a openannotation:Annotation;

        openannotation:hasBody <#{body_url}>;
        openannotation:hasTarget [
          a openannotation:SpecificResource;
          openannotation:hasSelector [
            a openannotation:FragmentSelector;
            dc:conformsTo <#{conforms_to_url}>;
            rdf:value \"#{frag_value}\"
          ];
          openannotation:hasSource <#{source_url}>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] ."
    g = write_anno.graph
    expect(g.size).to eql 10
    expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.hasBody, RDF::URI(body_url)]).size).to eql 1
    target_solns = g.query([nil, RDF::OpenAnnotation.hasTarget, nil])
    expect(target_solns.size).to eql 1
    target_node = target_solns.first.object
    expect(g.query([target_node, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
    expect(g.query([target_node, RDF::OpenAnnotation.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = g.query([target_node, RDF::OpenAnnotation.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_node = selector_solns.first.object
    expect(g.query([selector_node, RDF.type, RDF::OpenAnnotation.FragmentSelector]).size).to eql 1
    expect(g.query([selector_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]).size).to eql 1
    expect(g.query([selector_node, RDF.value, frag_value]).size).to eql 1

    id = write_anno.save
    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql 10
    anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.hasBody, RDF::URI(body_url)]).size).to eql 1
    target_solns = h.query([anno_uri_obj, RDF::OpenAnnotation.hasTarget, nil])
    expect(target_solns.size).to eql 1
    target_node = target_solns.first.object
    expect(h.query([target_node, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
    expect(h.query([target_node, RDF::OpenAnnotation.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = h.query([target_node, RDF::OpenAnnotation.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_node = selector_solns.first.object
    expect(h.query([selector_node, RDF.type, RDF::OpenAnnotation.FragmentSelector]).size).to eql 1
    expect(h.query([selector_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]).size).to eql 1
    expect(h.query([selector_node, RDF.value, frag_value]).size).to eql 1
  end
  it "body is FragmentSelector" do
    target_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    conforms_to_url = "http://www.w3.org/TR/media-frags/"
    frag_value = "xywh=0,0,200,200"
    write_anno = Triannon::Annotation.new data: "
    @prefix dc: <http://purl.org/dc/terms/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

     [
        a openannotation:Annotation;

        openannotation:hasTarget <#{target_url}>;
        openannotation:hasBody [
          a openannotation:SpecificResource;
          openannotation:hasSelector [
            a openannotation:FragmentSelector;
            dc:conformsTo <#{conforms_to_url}>;
            rdf:value \"#{frag_value}\"
          ];
          openannotation:hasSource <#{source_url}>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] ."
    g = write_anno.graph
    expect(g.size).to eql 10
    expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = g.query([nil, RDF::OpenAnnotation.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(g.query([body_node, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
    expect(g.query([body_node, RDF::OpenAnnotation.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = g.query([body_node, RDF::OpenAnnotation.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_node = selector_solns.first.object
    expect(g.query([selector_node, RDF.type, RDF::OpenAnnotation.FragmentSelector]).size).to eql 1
    expect(g.query([selector_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]).size).to eql 1
    expect(g.query([selector_node, RDF.value, frag_value]).size).to eql 1

    id = write_anno.save
    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql 10
    anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = h.query([anno_uri_obj, RDF::OpenAnnotation.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_node = body_solns.first.object
    expect(h.query([body_node, RDF.type, RDF::OpenAnnotation.SpecificResource]).size).to eql 1
    expect(h.query([body_node, RDF::OpenAnnotation.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = h.query([body_node, RDF::OpenAnnotation.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_node = selector_solns.first.object
    expect(h.query([selector_node, RDF.type, RDF::OpenAnnotation.FragmentSelector]).size).to eql 1
    expect(h.query([selector_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]).size).to eql 1
    expect(h.query([selector_node, RDF.value, frag_value]).size).to eql 1
  end
  
  it "target is TextPositionSelector" do
    skip 'need to implement this test'
  end
  it "body is TextPositionSelector" do
    skip 'need to implement this test'
  end

  it "target is TextQuoteSelector" do
    skip 'need to implement this test'
  end
  it "body is TextQuoteSelector" do
    skip 'need to implement this test'
  end

  it "source has additional metadata (beyond the url)" do
    skip 'need to implement this test'
    # see fragment selector tests
    write_anno = Triannon::Annotation.new data: '
    @prefix content: <http://www.w3.org/2011/content#> .
    @prefix dc: <http://purl.org/dc/terms/> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg> a dcmitype:Image .

     [
        a openannotation:Annotation;

        openannotation:hasBody <http://dbpedia.org/resource/Otto_Ege>;
        openannotation:hasTarget [
          a openannotation:SpecificResource;
          openannotation:hasSelector [
            a openannotation:FragmentSelector;
            dc:conformsTo <http://www.w3.org/TR/media-frags/>;
            rdf:value "xywh=0,0,200,200"
          ];
          openannotation:hasSource <https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] .'
    g = write_anno.graph
  end
  it "DataPositionSelector" do
    skip 'DataPositionSelector not yet implemented'
  end
  it "SvgSelector" do
    skip 'SvgSelector not yet implemented'
  end

end