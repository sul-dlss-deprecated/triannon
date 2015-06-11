require 'spec_helper'

describe "integration tests for no body", :vcr do

  before(:all) do
    @root_container = 'no_body_integration_specs'
    vcr_cassette_name = "integration_tests_for_no_body/before_spec"
    create_root_container(@root_container, vcr_cassette_name)
  end
  after(:all) do
    ldp_testing_container_urls = ["#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"]
    vcr_cassette_name = "integration_tests_for_no_body/after_spec"
    delete_test_objects(ldp_testing_container_urls, [], @root_container, vcr_cassette_name)
  end

  it 'bookmark' do
    write_anno = Triannon::Annotation.new(root_container: @root_container, data: '{
      "@context": "http://www.w3.org/ns/oa-context-20130208.json",
      "@type": "oa:Annotation",
      "motivatedBy": "oa:bookmarking",
      "hasTarget": "http://purl.stanford.edu/kq131cs7229"
    }')
    g = write_anno.graph
    expect(g.size).to eql 3
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.bookmarking]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find(@root_container, id)
    h = anno.graph
    expect(h.size).to eql 3
    anno_uri_obj = RDF::URI.new("#{triannon_base_url}/#{@root_container}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.bookmarking]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI("http://purl.stanford.edu/kq131cs7229")]).size).to eql 1
  end

end
