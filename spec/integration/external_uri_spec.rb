require 'spec_helper'

vcr_options = {:re_record_interval => 45.days}  # TODO will make shorter once we have jetty running fedora4
describe "integration tests for annos with external URIs", :vcr => vcr_options do

  it 'target has external URI' do
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new data: 
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasTarget <#{target_uri}>;
        openannotation:motivatedBy openannotation:bookmarking
     ] ."
     g = write_anno.graph
     expect(g.size).to eql 3
     expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
     expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.bookmarking]).size).to eql 1
     expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri)]).size).to eql 1
     
     id = write_anno.save
     anno = Triannon::Annotation.find id
     h = anno.graph
     expect(h.size).to eql 3
     uri_resource = RDF::URI("#{Triannon.config[:triannon_base_url]}/#{id}")
     expect(h.query([uri_resource, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
     expect(h.query([uri_resource, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.bookmarking]).size).to eql 1
     expect(h.query([uri_resource, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri)]).size).to eql 1     
  end
  
  it 'mult targets with external URIs' do
    target_uri1 = "http://purl.stanford.edu/cd666ef4444"
    target_uri2 = "http://purl.stanford.edu/ab123cd4567"
    write_anno = Triannon::Annotation.new data: 
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasTarget <#{target_uri1}>,
           <#{target_uri2}>;
        openannotation:motivatedBy openannotation:bookmarking
     ] ."
     g = write_anno.graph
     expect(g.size).to eql 4
     expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
     expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.bookmarking]).size).to eql 1
     expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri1)]).size).to eql 1
     expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri2)]).size).to eql 1
     
     id = write_anno.save
     
     anno = Triannon::Annotation.find id
     h = anno.graph
     expect(h.size).to eql 4
     uri_resource = RDF::URI("#{Triannon.config[:triannon_base_url]}/#{id}")
     expect(h.query([uri_resource, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
     expect(h.query([uri_resource, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.bookmarking]).size).to eql 1
     expect(h.query([uri_resource, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri1)]).size).to eql 1     
     expect(h.query([uri_resource, RDF::OpenAnnotation.hasTarget, RDF::URI(target_uri2)]).size).to eql 1     
  end

  it 'body and target have plain external URI' do
    skip "need to implement external URI for bodies"
    body_uri = "http://dbpedia.org/resource/Otto_Ege"
    target_uri = "http://purl.stanford.edu/kq131cs7229"
    write_anno = Triannon::Annotation.new data: 
    "@prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

     [
        a openannotation:Annotation;
        openannotation:hasBody <#{body_uri}>;
        openannotation:hasTarget <#{target_uri}>;
        openannotation:motivatedBy openannotation:identifying
     ] ."
    g = write_anno.graph
    expect(g.size).to eql 4
    expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.identifying]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.hasBody, RDF::URI("http://dbpedia.org/resource/Otto_Ege")]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1

    id = write_anno.save
    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql 4
    uri_resource = RDF::URI("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([uri_resource, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(h.query([uri_resource, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.identifying]).size).to eql 1
    expect(g.query([uri_resource, RDF::OpenAnnotation.hasBody, RDF::URI("http://dbpedia.org/resource/Otto_Ege")]).size).to eql 1
    expect(h.query([uri_resource, RDF::OpenAnnotation.hasTarget, RDF::URI("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1
  end
  
  it 'target uri has additional properties' do
    skip "need to implement addl props for targets"
  end
  
  it 'body uri has additional properties' do
    skip "need to implement addl props for bodies"
  end
  
end