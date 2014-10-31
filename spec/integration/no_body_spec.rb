require 'spec_helper'

vcr_options = {:re_record_interval => 45.days}  # TODO will make shorter once we have jetty running fedora4
describe "integration tests for annos with no body", :vcr => vcr_options do

  it 'bookmark' do
    write_anno = Triannon::Annotation.new data: '{
      "@context": "http://www.w3.org/ns/oa-context-20130208.json",
      "@type": "oa:Annotation",
      "motivatedBy": "oa:bookmarking", 
      "hasTarget": "http://purl.stanford.edu/kq131cs7229"
    }'
    g = write_anno.graph
    expect(g.size).to eql 3
    expect(g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.bookmarking]).size).to eql 1
    expect(g.query([nil, RDF::OpenAnnotation.hasTarget, RDF::URI("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1

    id = write_anno.save
    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql 3
    anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::OpenAnnotation.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.motivatedBy, RDF::OpenAnnotation.bookmarking]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::OpenAnnotation.hasTarget, RDF::URI("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1
  end
  
end