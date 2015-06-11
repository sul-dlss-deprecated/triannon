require 'spec_helper'

describe "integration tests for SpecificResource", :vcr do
  before(:all) do
    @root_container = 'specific_res_integration_specs'
    vcr_cassette_name = "integration_tests_for_SpecificResource/before_spec"
    create_root_container(@root_container, vcr_cassette_name)
  end
  after(:all) do
    ldp_testing_container_urls = ["#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"]
    vcr_cassette_name = "integration_tests_for_SpecificResource/after_spec"
    delete_test_objects(ldp_testing_container_urls, [], @root_container, vcr_cassette_name)
  end

  it "target is FragmentSelector" do
    body_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    conforms_to_url = "http://www.w3.org/TR/media-frags/"
    frag_value = "xywh=0,0,200,200"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data: "
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
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 10
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
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
    expect(sel_contents_solns).to include [selector_blank_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF.value, frag_value]

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{triannon_base_url}/#{@root_container}/#{id}")
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
  end
  it "body is FragmentSelector" do
    target_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    conforms_to_url = "http://www.w3.org/TR/media-frags/"
    frag_value = "xywh=0,0,200,200"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data: "
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
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 10
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_blank_node = body_solns.first.object
    expect(g.query([body_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(g.query([body_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = g.query([body_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = g.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 3
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.FragmentSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF.value, frag_value]

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_blank_node = body_solns.first.object
    expect(h.query([body_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(h.query([body_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = h.query([body_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = h.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 3
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.FragmentSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF.value, frag_value]
  end

  it "target is TextPositionSelector" do
    body_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data: "
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
            a openannotation:TextPositionSelector;
            openannotation:end \"66\"^^xsd:nonNegativeInteger;
            openannotation:start \"0\"^^xsd:nonNegativeInteger
          ];
          openannotation:hasSource <#{source_url}>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 10
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
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
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextPositionSelector]
    start_obj_solns = g.query [selector_blank_node, RDF::Vocab::OA.start, nil]
    expect(start_obj_solns.count).to eq 1
    start_obj = start_obj_solns.first.object
    expect(start_obj.to_s).to eql "0"
    expect(start_obj.datatype).to eql RDF::XSD.nonNegativeInteger
    end_obj_solns = g.query [selector_blank_node, RDF::Vocab::OA.end, nil]
    expect(end_obj_solns.count).to eq 1
    end_obj = end_obj_solns.first.object
    expect(end_obj.to_s).to eql "66"
    expect(end_obj.datatype).to eql RDF::XSD.nonNegativeInteger

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{triannon_base_url}/#{@root_container}/#{id}")
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
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextPositionSelector]
    start_obj_solns = h.query [selector_blank_node, RDF::Vocab::OA.start, nil]
    expect(start_obj_solns.count).to eq 1
    start_obj = start_obj_solns.first.object
    expect(start_obj.to_s).to eql "0"
    expect(start_obj.datatype).to eql RDF::XSD.nonNegativeInteger
    end_obj_solns = h.query [selector_blank_node, RDF::Vocab::OA.end, nil]
    expect(end_obj_solns.count).to eq 1
    end_obj = end_obj_solns.first.object
    expect(end_obj.to_s).to eql "66"
    expect(end_obj.datatype).to eql RDF::XSD.nonNegativeInteger
  end
  it "body is TextPositionSelector" do
    target_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data: "
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
            a openannotation:TextPositionSelector;
            openannotation:end \"66\"^^xsd:nonNegativeInteger;
            openannotation:start \"0\"^^xsd:nonNegativeInteger
          ];
          openannotation:hasSource <#{source_url}>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 10
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_blank_node = body_solns.first.object
    expect(g.query([body_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(g.query([body_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = g.query([body_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = g.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 3
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextPositionSelector]
    start_obj_solns = g.query [selector_blank_node, RDF::Vocab::OA.start, nil]
    expect(start_obj_solns.count).to eq 1
    start_obj = start_obj_solns.first.object
    expect(start_obj.to_s).to eql "0"
    expect(start_obj.datatype).to eql RDF::XSD.nonNegativeInteger
    end_obj_solns = g.query [selector_blank_node, RDF::Vocab::OA.end, nil]
    expect(end_obj_solns.count).to eq 1
    end_obj = end_obj_solns.first.object
    expect(end_obj.to_s).to eql "66"
    expect(end_obj.datatype).to eql RDF::XSD.nonNegativeInteger

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_blank_node = body_solns.first.object
    expect(h.query([body_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(h.query([body_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = h.query([body_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = h.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 3
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextPositionSelector]
    start_obj_solns = h.query [selector_blank_node, RDF::Vocab::OA.start, nil]
    expect(start_obj_solns.count).to eq 1
    start_obj = start_obj_solns.first.object
    expect(start_obj.to_s).to eql "0"
    expect(start_obj.datatype).to eql RDF::XSD.nonNegativeInteger
    end_obj_solns = h.query [selector_blank_node, RDF::Vocab::OA.end, nil]
    expect(end_obj_solns.count).to eq 1
    end_obj = end_obj_solns.first.object
    expect(end_obj.to_s).to eql "66"
    expect(end_obj.datatype).to eql RDF::XSD.nonNegativeInteger
  end

  it "target is TextQuoteSelector" do
    body_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    exact_str = "third and fourth Gospels"
    prefix_str = "manuscript which comprised the "
    suffix_str = " and The Canonical Epistles,"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data: "
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

     [
        a openannotation:Annotation;

        openannotation:hasBody <#{body_url}>;
        openannotation:hasTarget [
          a openannotation:SpecificResource;
          openannotation:hasSelector [
            a openannotation:TextQuoteSelector;
            openannotation:exact \"#{exact_str}\";
            openannotation:prefix \"#{prefix_str}\";
            openannotation:suffix \"#{suffix_str}\"
          ];
          openannotation:hasSource <#{source_url}>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 11
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
    target_solns = g.query([nil, RDF::Vocab::OA.hasTarget, nil])
    expect(target_solns.size).to eql 1
    target_blank_node = target_solns.first.object
    expect(g.query([target_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(g.query([target_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = g.query([target_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = g.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 4
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextQuoteSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.exact, RDF::Literal.new(exact_str)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.prefix, RDF::Literal.new(prefix_str)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.suffix, RDF::Literal.new(suffix_str)]

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{triannon_base_url}/#{@root_container}/#{id}")
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
    expect(sel_contents_solns.size).to eql 4
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextQuoteSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.exact, RDF::Literal.new(exact_str)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.prefix, RDF::Literal.new(prefix_str)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.suffix, RDF::Literal.new(suffix_str)]
  end
  it "body is TextQuoteSelector" do
    target_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    exact_str = "third and fourth Gospels"
    prefix_str = "manuscript which comprised the "
    suffix_str = " and The Canonical Epistles,"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data: "
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

     [
        a openannotation:Annotation;

        openannotation:hasTarget <#{target_url}>;
        openannotation:hasBody [
          a openannotation:SpecificResource;
          openannotation:hasSelector [
            a openannotation:TextQuoteSelector;
            openannotation:exact \"#{exact_str}\";
            openannotation:prefix \"#{prefix_str}\";
            openannotation:suffix \"#{suffix_str}\"
          ];
          openannotation:hasSource <#{source_url}>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 11
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_blank_node = body_solns.first.object
    expect(g.query([body_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(g.query([body_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = g.query([body_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = g.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 4
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextQuoteSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.exact, RDF::Literal.new(exact_str)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.prefix, RDF::Literal.new(prefix_str)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.suffix, RDF::Literal.new(suffix_str)]

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_blank_node = body_solns.first.object
    expect(h.query([body_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    expect(h.query([body_blank_node, RDF::Vocab::OA.hasSource, RDF::URI(source_url)]).size).to eql 1
    selector_solns = h.query([body_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = h.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 4
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.TextQuoteSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.exact, RDF::Literal.new(exact_str)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.prefix, RDF::Literal.new(prefix_str)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::Vocab::OA.suffix, RDF::Literal.new(suffix_str)]
  end

  it "source uri has additional metadata" do
    body_url = "http://dbpedia.org/resource/Otto_Ege"
    source_url = "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"
    conforms_to_url = "http://www.w3.org/TR/media-frags/"
    frag_value = "xywh=0,0,200,200"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data: "
    @prefix dc: <http://purl.org/dc/terms/> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <#{source_url}> a dcmitype:Image .

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
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 11
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
    target_solns = g.query([nil, RDF::Vocab::OA.hasTarget, nil])
    expect(target_solns.size).to eql 1
    target_blank_node = target_solns.first.object
    expect(g.query([target_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    source_obj = RDF::URI.new(source_url)
    expect(g.query([target_blank_node, RDF::Vocab::OA.hasSource, source_obj]).size).to eql 1
    expect(g.query([source_obj, RDF.type, RDF::Vocab::DCMIType.Image]).size).to eql 1
    selector_solns = g.query([target_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = g.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 3
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.FragmentSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF.value, frag_value]

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
    target_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, nil])
    expect(target_solns.size).to eql 1
    target_blank_node = target_solns.first.object
    expect(h.query([target_blank_node, RDF.type, RDF::Vocab::OA.SpecificResource]).size).to eql 1
    source_obj = RDF::URI.new(source_url)
    expect(h.query([target_blank_node, RDF::Vocab::OA.hasSource, source_obj]).size).to eql 1
    expect(h.query([source_obj, RDF.type, RDF::Vocab::DCMIType.Image]).size).to eql 1
    selector_solns = h.query([target_blank_node, RDF::Vocab::OA.hasSelector, nil])
    expect(selector_solns.size).to eql 1
    selector_blank_node = selector_solns.first.object
    sel_contents_solns = h.query([selector_blank_node, nil, nil])
    expect(sel_contents_solns.size).to eql 3
    expect(sel_contents_solns).to include [selector_blank_node, RDF.type, RDF::Vocab::OA.FragmentSelector]
    expect(sel_contents_solns).to include [selector_blank_node, RDF::DC.conformsTo, RDF::URI(conforms_to_url)]
    expect(sel_contents_solns).to include [selector_blank_node, RDF.value, frag_value]
  end

  #it "DataPositionSelector" do
  #  skip 'DataPositionSelector not yet implemented'
  #end
  #it "SvgSelector" do
  #  skip 'SvgSelector not yet implemented'
  #end

end
