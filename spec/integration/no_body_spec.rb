require 'spec_helper'

describe "integration tests for no body", :vcr do

  it 'bookmark' do
    write_anno = Triannon::Annotation.new data: '{
      "@context": "http://www.w3.org/ns/oa-context-20130208.json",
      "@type": "oa:Annotation",
      "motivatedBy": "oa:bookmarking", 
      "hasTarget": "http://purl.stanford.edu/kq131cs7229"
    }'
    g = write_anno.graph
    expect(g.size).to eql 3
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.bookmarking]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql 3
    anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.bookmarking]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1
  end
  
end