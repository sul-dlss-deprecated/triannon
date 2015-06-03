require 'spec_helper'

describe Triannon::Annotation, :vcr do

=begin
  before(:all) do
    @solr_ids_to_delete_after_testing = []
    @solr_baseurl = Triannon.config[:solr_url]
  end
  after(:all) do
    cassette_name = "Triannon_SolrWriter/after_spec"
    VCR.insert_cassette(cassette_name)
    rsolr_client = RSolr.connect :url => Triannon.config[:solr_url]
      @solr_ids_to_delete_after_testing.uniq.each { |doc_id|
      rsolr_client.delete_by_id(doc_id)
    }
    rsolr_client.commit
    VCR.eject_cassette(cassette_name)
  end
=end


  before(:all) do
    @cntnrs_to_delete_after_testing = []
    @ldp_url = Triannon.config[:ldp]['url'].strip
    @ldp_url.chop! if @ldp_url.end_with?('/')
    @uber_cont = Triannon.config[:ldp]['uber_container'].strip
    @uber_cont = @uber_cont[1..-1] if @uber_cont.start_with?('/')
    @uber_cont.chop! if @uber_cont.end_with?('/')
    @uber_root_url = "#{@ldp_url}/#{@uber_cont}"
    @root_container = 'annomodelspecs'
    @root_url = "#{@uber_root_url}/#{@root_container}"
    cassette_name = "Triannon_Annotation/before_spec"
    VCR.insert_cassette(cassette_name)
    begin
      Triannon::LdpWriter.create_basic_container(nil, @uber_cont)
      Triannon::LdpWriter.create_basic_container(@uber_cont, @root_container)
    rescue Faraday::ConnectionFailed
      # probably here due to vcr cassette
    end
    VCR.eject_cassette(cassette_name)
  end
  after(:all) do
    cassette_name = "Triannon_Annotation/after_spec"
    VCR.insert_cassette(cassette_name)
    @cntnrs_to_delete_after_testing << "#{@root_url}"
    @cntnrs_to_delete_after_testing.uniq.each { |cont_url|
      begin
        if Triannon::LdpWriter.container_exist?(cont_url.split("#{@ldp_url}/").last)
          Triannon::LdpWriter.delete_container cont_url
          Faraday.new(url: "#{cont_url}/fcr:tombstone").delete
        end
      rescue Triannon::LDPStorageError => e
        # probably here due to parent container being deleted first
      rescue Faraday::ConnectionFailed
        # probably here due to vcr cassette
      end
    }
    VCR.eject_cassette(cassette_name)
  end
  let(:bookmark_anno) {Triannon::Annotation.new(data: Triannon.annotation_fixture("bookmark.json"), root_container: @root_container)}

  it "doesn't do external lookup of json_ld context", :vcr => {:record => :none} do
    # NOTE:  VCR would throw an error if this does an external lookup
    # https://www.relishapp.com/vcr/vcr/v/2-9-3/docs/record-modes/none
    expect(bookmark_anno.graph).to be_a_kind_of OA::Graph
  end

  it "#jsonld_oa calls OA::Graph #jsonld_oa" do
    expect(bookmark_anno.graph).to be_a OA::Graph
    expect(bookmark_anno.graph).to receive(:jsonld_oa)
    bookmark_anno.jsonld_oa
  end

  it "#jsonld_iiif calls OA::Graph #jsonld_iiif" do
    expect(bookmark_anno.graph).to be_a OA::Graph
    expect(bookmark_anno.graph).to receive(:jsonld_iiif)
    bookmark_anno.jsonld_iiif
  end

  it "#graph is a OA::Graph" do
    expect(bookmark_anno.graph).to be_a OA::Graph
  end

  context '#graph=' do
    it "works with OA::Graph as param" do
      bookmark_anno.graph = OA::Graph.new RDF::Graph.new
      expect(bookmark_anno.graph).to be_a OA::Graph
    end
    it "works with RDF::Graph as param" do
      bookmark_anno.graph = RDF::Graph.new
      expect(bookmark_anno.graph).to be_a OA::Graph
    end
  end

  context "#data_as_graph" do
    let(:json_ld_data) { Triannon.annotation_fixture("bookmark.json") }

    it "does Mime::Type.lookup if expected_content_type" do
      anno = Triannon::Annotation.new({data: json_ld_data, expected_content_type: "application/ld+json", root_container: @root_container})
      expect(Mime::Type).to receive(:lookup).with("application/ld+json").and_call_original
      expect(anno.graph).to be_a_kind_of OA::Graph
    end
    it "does NOT do Mime::Type.lookup if no expected_content_type" do
      anno = Triannon::Annotation.new(data: json_ld_data, root_container: @root_container)
      expect(Mime::Type).not_to receive(:lookup)
      expect(anno.graph).to be_a_kind_of OA::Graph
    end
    context "json-ld data" do
      it "populates graph from json-ld" do
        expect(json_ld_data).to match(/\A\{.+\}\Z/m) # (Note:  \A and \Z and m are needed instead of ^$ due to \n in data)
        anno = Triannon::Annotation.new(data: json_ld_data, root_container: @root_container)
        expect(anno.graph).to be_a_kind_of OA::Graph
        expect(anno.graph.count).to be > 1
      end
      it "is rejected if first and last non whitespace characters aren't { and }" do
        anno = Triannon::Annotation.new(data: "xxx " + json_ld_data, root_container: @root_container)
        expect(anno.graph).to be_nil
      end
      it "converts data to turtle" do
        anno = Triannon::Annotation.new(data: json_ld_data, root_container: @root_container)
        c = anno.graph.count
        g = RDF::Graph.new
        g.from_ttl(anno.data)
        expect(g.count).to eql c
      end
    end
    context "turtle data" do
      let(:ttl_data) { Triannon.annotation_fixture("body-chars.ttl") }

      it "populates graph from ttl" do
        expect(ttl_data).to match(/\.\Z/)  # (Note:  \Z is needed instead of $ due to \n in data)
        anno = Triannon::Annotation.new(data: ttl_data, root_container: @root_container)
        expect(anno.graph).to be_a_kind_of OA::Graph
        expect(anno.graph.count).to be > 1
      end
      it "is rejected if it doesn't end in period" do
        anno = Triannon::Annotation.new(data: ttl_data + "xxx", root_container: @root_container)
        expect(anno.graph).to be_nil
      end
    end
    context "rdf(xml) data" do
      let(:rdfxml_data) { Triannon.annotation_fixture("body-chars.rdf") }

      it "populates graph from rdfxml" do
        expect(rdfxml_data).to match(/\A<.+>\Z/m) # (Note:  \A and \Z and m are needed instead of ^$ due to \n in data)
        anno = Triannon::Annotation.new(data: rdfxml_data, root_container: @root_container)
        expect(anno.graph).to be_a_kind_of OA::Graph
        expect(anno.graph.count).to be > 1
      end
      it "is rejected if first and last non whitespace characters aren't < and >" do
        anno = Triannon::Annotation.new(data: "xxx " + rdfxml_data, root_container: @root_container)
        expect(anno.graph).to be_nil
      end
      it "converts data to turtle" do
        anno = Triannon::Annotation.new(data: rdfxml_data, root_container: @root_container)
        c = anno.graph.count
        g = RDF::Graph.new
        g.from_ttl(anno.data)
        expect(g.count).to eql c
      end
    end
  end # data_as_graph

  context "parsing graph" do
    context '#id_as_url' do
      it "calls OA::Graph #id_as_url" do
        expect(bookmark_anno.graph).to be_a OA::Graph
        expect(bookmark_anno.graph).to receive(:id_as_url)
        bookmark_anno.id_as_url
      end
      it "returns nil if there is no graph" do
        anno = Triannon::Annotation.new
        expect(anno.id_as_url).to eq nil
      end
    end
    context '#motivated_by' do
      it "calls OA::Graph #motivated_by" do
        expect(bookmark_anno.graph).to be_a OA::Graph
        expect(bookmark_anno.graph).to receive(:motivated_by)
        bookmark_anno.motivated_by
      end
      it "returns nil if there is no graph" do
        anno = Triannon::Annotation.new
        expect(anno.motivated_by).to eq nil
      end
    end
  end # parsing graph

  context '#save' do
    it "sets anno id" do
      anno_id = bookmark_anno.save
      expect(bookmark_anno.id).to eq anno_id
    end
    it "reloads graph from storage to ensure id is in the graph" do
      expect(Triannon::LdpLoader).to receive(:load).and_call_original
      anno_id = bookmark_anno.save
      expect(bookmark_anno.graph.id_as_url).to match bookmark_anno.id
    end
    it "calls solr_save method after successful save to LDP Store" do
      # test to make sure callback logic implemented properly in model
      expect(bookmark_anno).to receive(:solr_save)
      bookmark_anno.save
    end
    it "doesn't call solr_save method after unsuccessful save to LDP Store - nil returned" do
      # test to make sure callback logic implemented properly in model
      allow(bookmark_anno).to receive(:save).and_return(nil) # or it might raise an exception
      expect(bookmark_anno).not_to receive(:solr_save)
      bookmark_anno.save
    end
    it "doesn't call solr_save method after exception for LDP store create" do
      # test to make sure callback logic implemented properly in model
      allow(bookmark_anno).to receive(:create).and_raise(RuntimeError)
      expect(bookmark_anno).not_to receive(:solr_save)
      expect{bookmark_anno.save}.to raise_error
    end
    it "returns false if graph is nil" do
      allow(bookmark_anno).to receive(:graph).and_return(nil)
      expect(bookmark_anno.save).to be_falsey
    end
    it "returns false if graph size is 0" do
      allow(bookmark_anno).to receive(:graph).and_return(OA::Graph.new RDF::Graph.new)
      expect(bookmark_anno.save).to be_falsey
    end
  end

  context "#destroy" do
    it "calls LdpWriter.delete_anno with its own id" do
      id = 'someid'
      a = Triannon::Annotation.new(id: id, root_container: @root_container)
      allow(a.send(:solr_writer)).to receive(:delete)
      expect(Triannon::LdpWriter).to receive(:delete_anno).with("#{@root_container}/#{id}")
      a.destroy
    end
    it "calls solr_delete method after successful destroy in LDP store" do
      # test to make sure callback logic implemented properly in model
      bookmark_anno.save
      expect(bookmark_anno).to receive(:solr_delete)
      bookmark_anno.destroy
    end
    it "doesn't call solr_save method after unsuccessful save to LDP Store - nil returned" do
      # test to make sure callback logic implemented properly in model
      allow(bookmark_anno).to receive(:destroy).and_return(nil) # or it might raise an exception
      expect(bookmark_anno).not_to receive(:solr_save)
      bookmark_anno.destroy
    end
    it "doesn't call solr_delete method after exception for LDP store destroy" do
      # test to make sure callback logic implemented properly in model
      allow(bookmark_anno).to receive(:destroy).and_raise(RuntimeError)
      expect(bookmark_anno).not_to receive(:solr_delete)
      expect{bookmark_anno.destroy}.to raise_error
    end
  end

  context '#solr_save' do
    let(:my_bookmark_anno) {
      # make sure we have id for anno
      id = bookmark_anno.save
      Triannon::Annotation.find(id, @root_container)
    }
    let(:solr_writer) { my_bookmark_anno.send(:solr_writer) }
    it "calls SolrWriter write with triannon graph" do
      expect(solr_writer).to receive(:write).with(my_bookmark_anno.graph, @root_container)
      my_bookmark_anno.send(:solr_save)
    end
    it "does NOT call SolrWriter write when graph is nil" do
      expect(bookmark_anno.graph.id_as_url).to eq nil
      expect(solr_writer).not_to receive(:write)
      bookmark_anno.send(:solr_save)
    end
    it "does NOT call SolrWriter write when graph has no id" do
      allow(bookmark_anno.graph).to receive(:id_as_url).and_return("")
      expect(solr_writer).not_to receive(:write)
      bookmark_anno.send(:solr_save)
    end
    it "raises exception when Solr add is not successful" do
      allow(Triannon::SolrWriter).to receive(:solr_hash).with(my_bookmark_anno.graph).and_return({:id => 'test'})
      allow(solr_writer).to receive(:add).and_raise(RuntimeError)
      expect { my_bookmark_anno.send(:solr_save) }.to raise_error
    end
  end

  context '#solr_delete' do
    let(:solr_writer) { bookmark_anno.send(:solr_writer) }
    it "calls SolrWriter.delete with id" do
      allow(bookmark_anno).to receive(:id).and_return("666")
      expect(solr_writer).to receive(:delete).with(bookmark_anno.id)
      bookmark_anno.send(:solr_delete)
    end
    it "raises exception when Solr delete is not successful" do
      allow(bookmark_anno).to receive(:id).and_return("666")
      allow(solr_writer).to receive(:delete).and_raise(RuntimeError)
      expect { bookmark_anno.send(:solr_delete) }.to raise_error
    end
  end

  context '*find' do
    it "sets anno id" do
      anno = Triannon::Annotation.new(data: Triannon.annotation_fixture("body-chars.ttl"), root_container: @root_container)
      anno_id = anno.save
      my_anno = Triannon::Annotation.find(anno_id, @root_container)
      expect(my_anno.id).to eq anno_id
    end
  end

end
