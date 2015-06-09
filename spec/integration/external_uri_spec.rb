require 'spec_helper'

describe "integration tests for external URIs", :vcr do

  before(:all) do
    @root_container = 'external_uri_specs'
    vcr_cassette_name = "integration_tests_for_external_URIs/before_spec"
    create_root_container(@root_container, vcr_cassette_name)
  end
  after(:all) do
    ldp_testing_container_urls = ["#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"]
    vcr_cassette_name = "integration_tests_for_external_URIs/after_spec"
    delete_test_objects(ldp_testing_container_urls, [], @root_container, vcr_cassette_name)
  end

  it 'target has external URI' do
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasTarget <#{target_uri}>;
        openannotation:motivatedBy openannotation:bookmarking
     ] .")
     g = write_anno.graph
     expect(g.size).to eql 3
     expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.bookmarking]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1

     sw = write_anno.send(:solr_writer)
     allow(sw).to receive(:add)
     id = write_anno.save

     anno = Triannon::Annotation.find(id, @root_container)
     h = anno.graph
     expect(h.size).to eql 3
     anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
     expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.bookmarking]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
  end

  it 'mult targets with plain external URIs' do
    target_uri1 = "http://purl.stanford.edu/cd666ef4444"
    target_uri2 = "http://purl.stanford.edu/ab123cd4567"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasTarget <#{target_uri1}>,
           <#{target_uri2}>;
        openannotation:motivatedBy openannotation:bookmarking
     ] .")
     g = write_anno.graph
     expect(g.size).to eql 4
     expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.bookmarking]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri1)]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri2)]).size).to eql 1

     sw = write_anno.send(:solr_writer)
     allow(sw).to receive(:add)
     id = write_anno.save

     anno = Triannon::Annotation.find(id, @root_container)
     h = anno.graph
     expect(h.size).to eql 4
     anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
     expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.bookmarking]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri1)]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri2)]).size).to eql 1
  end

  it 'body and target have plain external URI' do
    body_uri = "http://dbpedia.org/resource/Otto_Ege"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasBody <#{body_uri}>;
        openannotation:hasTarget <#{target_uri}>;
        openannotation:motivatedBy openannotation:identifying
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 4
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_uri)]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(id, @root_container)
    h = anno.graph
    expect(h.size).to eql 4
    anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_uri)]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
  end

  it "mult bodies with plain external URIs" do
    body_uri1 = "http://dbpedia.org/resource/Otto_Ege"
    body_uri2 = "http://dbpedia.org/resource/Love"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasBody <#{body_uri1}>,
           <#{body_uri2}>;
        openannotation:hasTarget <#{target_uri}>;
        openannotation:motivatedBy openannotation:identifying
     ] .")
    g = write_anno.graph
    expect(g.size).to eql 5
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_uri1)]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_uri2)]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(id, @root_container)
    h = anno.graph
    expect(h.size).to eql 5
    anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_uri1)]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_uri2)]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
  end

  it 'target uri has additional properties' do
    target_format = "text/html"
    target_uri = "http://external.com/index.html"
    body_uri = "http://www.myaudioblog.com/post/1.mp3"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix dc11: <http://purl.org/dc/elements/1.1/> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasBody <#{body_uri}>;
        openannotation:hasTarget <#{target_uri}>;
        openannotation:motivatedBy openannotation:identifying
     ] .

     <#{target_uri}> a dcmitype:Text;
        dc11:format \"#{target_format}\" .")
    g = write_anno.graph
    expect(g.size).to eql 6
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    expect(g.query([RDF::URI(target_uri), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(g.query([RDF::URI(target_uri), RDF::DC11.format, target_format]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_uri)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(id, @root_container)
    h = anno.graph
    expect(h.size).to eql 6
    anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
    expect(h.query([RDF::URI(target_uri), RDF.type, RDF::Vocab::DCMIType.Text]).size).to eql 1
    expect(h.query([RDF::URI(target_uri), RDF::DC11.format, target_format]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_uri)]).size).to eql 1
  end

  it 'body uri with semantic tag' do
    body_uri = "http://dbpedia.org/resource/Otto_Ege"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasBody <#{body_uri}>;
        openannotation:hasTarget <#{target_uri}>;
        openannotation:motivatedBy openannotation:identifying
     ] .

     <#{body_uri}> a openannotation:SemanticTag .")
    g = write_anno.graph
    expect(g.size).to eql 5
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_uri)]).size).to eql 1
    expect(g.query([RDF::URI(body_uri), RDF.type, RDF::Vocab::OA.SemanticTag]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(id, @root_container)
    h = anno.graph
    expect(h.size).to eql 5
    anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_uri)]).size).to eql 1
    expect(h.query([RDF::URI(body_uri), RDF.type, RDF::Vocab::OA.SemanticTag]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
  end

  it "body uri with metadata" do
    body_uri = "http://www.myaudioblog.com/post/1.mp3"
    body_format = "audio/mpeg3"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new(root_container: @root_container, data:
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix dc11: <http://purl.org/dc/elements/1.1/> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasBody <#{body_uri}>;
        openannotation:hasTarget <#{target_uri}>;
        openannotation:motivatedBy openannotation:identifying
     ] .

     <#{body_uri}> a dcmitype:Sound;
        dc11:format \"#{body_format}\" .")
    g = write_anno.graph
    expect(g.size).to eql 6
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_uri)]).size).to eql 1
    expect(g.query([RDF::URI(body_uri), RDF.type, RDF::Vocab::DCMIType.Sound]).size).to eql 1
    expect(g.query([RDF::URI(body_uri), RDF::DC11.format, body_format]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(id, @root_container)
    h = anno.graph
    expect(h.size).to eql 6
    anno_uri_obj = RDF::URI("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_uri)]).size).to eql 1
    expect(h.query([RDF::URI(body_uri), RDF.type, RDF::Vocab::DCMIType.Sound]).size).to eql 1
    expect(h.query([RDF::URI(body_uri), RDF::DC11.format, body_format]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.identifying]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_uri)]).size).to eql 1
  end

end
