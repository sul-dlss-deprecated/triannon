require 'spec_helper'

describe Triannon::Annotation, :vcr do
  let(:bookmark_anno) {Triannon::Annotation.new data: Triannon.annotation_fixture("bookmark.json")}

  it "doesn't do external lookup of json_ld context" , :vcr => {:record => :none} do
    # NOTE:  VCR would throw an error if this does an external lookup
    # https://www.relishapp.com/vcr/vcr/v/2-9-3/docs/record-modes/none
    expect(bookmark_anno.graph).to be_a_kind_of Triannon::Graph
  end

  context 'json_ld replaces context url with inline context' do
    before(:each) do
      @json_b4_url = "{
                        \"@context\"  :     \""
      @json_after_url = "\"   ,
                        \"@id\": \"http://example.org/annos/annotation/foo.json\",
                        \"@type\": \"oa:Annotation\",
                        \"motivatedBy\": \"oa:bookmarking\",
                        \"hasTarget\": \"http://purl.stanford.edu/kq131cs7229\"
                      }"
      @oa_inline_context = File.read "lib/triannon/oa_context_20130208.json"
    end
    it "Triannon::JsonldContext::OA_DATED_CONTEXT_URL as url" do
      data_w_url = @json_b4_url + Triannon::JsonldContext::OA_DATED_CONTEXT_URL + @json_after_url
      anno = Triannon::Annotation.new data: data_w_url
      anno.send(:json_ld)
      expect(anno.data).to include(@oa_inline_context)
    end
    it "Triannon::JsonldContext::OA_CONTEXT_URL as url" do
      data_w_url = @json_b4_url + Triannon::JsonldContext::OA_CONTEXT_URL + @json_after_url
      anno = Triannon::Annotation.new data: data_w_url
      anno.send(:json_ld)
      expect(anno.data).to include(@oa_inline_context)
    end
    it "Triannon::JsonldContext::IIIF_CONTEXT_URL as url" do
      data_w_url = @json_b4_url + Triannon::JsonldContext::IIIF_CONTEXT_URL + @json_after_url
      anno = Triannon::Annotation.new data: data_w_url
      anno.send(:json_ld)
      expect(anno.data).to include(File.read "lib/triannon/iiif_presentation_2_context.json")
    end
  end
  
  it "#jsonld_oa calls Triannon::Graph #jsonld_oa" do
    expect(bookmark_anno.graph).to be_a Triannon::Graph
    expect(bookmark_anno.graph).to receive(:jsonld_oa)
    bookmark_anno.jsonld_oa
  end

  it "#jsonld_iiif calls Triannon::Graph #jsonld_iiif" do
    expect(bookmark_anno.graph).to be_a Triannon::Graph
    expect(bookmark_anno.graph).to receive(:jsonld_iiif)
    bookmark_anno.jsonld_iiif
  end

  it "#graph is a Triannon::Graph" do
    expect(bookmark_anno.graph).to be_a Triannon::Graph
  end
  
  context '#graph=' do
    it "works with Triannon::Graph as param" do
      bookmark_anno.graph = Triannon::Graph.new RDF::Graph.new
      expect(bookmark_anno.graph).to be_a Triannon::Graph
    end
    it "works with RDF::Graph as param" do
      bookmark_anno.graph = RDF::Graph.new
      expect(bookmark_anno.graph).to be_a Triannon::Graph
    end
  end
  
  context "#data_as_graph" do
    context "json-ld data" do
      before(:each) do
        @json_ld_data = Triannon.annotation_fixture("bookmark.json")
      end
      it "populates graph from json-ld" do
        expect(@json_ld_data).to match(/\A\{.+\}\Z/m) # (Note:  \A and \Z and m are needed instead of ^$ due to \n in data)
        anno = Triannon::Annotation.new data: @json_ld_data
        expect(anno.graph).to be_a_kind_of Triannon::Graph
        expect(anno.graph.count).to be > 1
      end
      it "is rejected if first and last non whitespace characters aren't { and }" do
        anno = Triannon::Annotation.new data: "xxx " + @json_ld_data
        expect(anno.graph).to be_nil
      end
      it "converts data to turtle" do
        anno = Triannon::Annotation.new data: @json_ld_data
        c = anno.graph.count
        g = RDF::Graph.new
        g.from_ttl(anno.data)
        expect(g.count).to eql c
      end
    end
    context "turtle data" do
      before(:each) do
        @ttl_data = Triannon.annotation_fixture("body-chars.ttl")
      end
      it "populates graph from ttl" do
        expect(@ttl_data).to match(/\.\Z/)  # (Note:  \Z is needed instead of $ due to \n in data)
        anno = Triannon::Annotation.new data: @ttl_data
        expect(anno.graph).to be_a_kind_of Triannon::Graph
        expect(anno.graph.count).to be > 1
      end
      it "is rejected if it doesn't end in period" do
        anno = Triannon::Annotation.new data: @ttl_data + "xxx"
        expect(anno.graph).to be_nil
      end
    end
    context "rdf(xml) data" do
      before(:each) do
        @rdfxml_data = Triannon.annotation_fixture("body-chars.rdf")
      end
      it "populates graph from rdfxml" do
        expect(@rdfxml_data).to match(/\A<.+>\Z/m) # (Note:  \A and \Z and m are needed instead of ^$ due to \n in data)
        anno = Triannon::Annotation.new data: @rdfxml_data
        expect(anno.graph).to be_a_kind_of Triannon::Graph
        expect(anno.graph.count).to be > 1
      end
      it "is rejected if first and last non whitespace characters aren't < and >" do
        anno = Triannon::Annotation.new data: "xxx " + @rdfxml_data
        expect(anno.graph).to be_nil
      end
    end
  end # data_as_graph

  context "parsing graph" do
    context '#id_as_url' do
      it "calls Triannon::Graph #id_as_url" do
        expect(bookmark_anno.graph).to be_a Triannon::Graph
        expect(bookmark_anno.graph).to receive(:id_as_url)
        bookmark_anno.id_as_url
      end
      it "returns nil if there is no graph" do
        anno = Triannon::Annotation.new
        expect(anno.id_as_url).to eq nil
      end
    end
    context '#motivated_by' do
      it "calls Triannon::Graph #motivated_by" do
        expect(bookmark_anno.graph).to be_a Triannon::Graph
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
  end

  context "#destroy" do
    it "calls LdpWriter.delete_anno with its own id" do
      id = 'someid'
      a = Triannon::Annotation.new :id => id
      allow(a.send(:solr_writer)).to receive(:delete)
      expect(Triannon::LdpWriter).to receive(:delete_anno).with(id)
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
      id = bookmark_anno.save
      Triannon::Annotation.find id
    }
    let(:solr_writer) { bookmark_anno.send(:solr_writer) }
    it "calls Triannon::LdpLoader.load" do
      allow(solr_writer).to receive(:add)
      expect(Triannon::LdpLoader).to receive(:load).with(my_bookmark_anno.id).and_call_original
      bookmark_anno.send(:solr_save)
    end
    it "calls solr_hash on triannon graph returned from LdpLoader" do
      tg = double("triannon_graph")
      allow(Triannon::LdpLoader).to receive(:load).with(my_bookmark_anno.id).and_return(tg)
      allow(solr_writer).to receive(:add)
      expect(tg).to receive(:solr_hash)
      bookmark_anno.send(:solr_save)
    end
    it "calls SolrWriter.add with solr_hash" do
      tg = double("triannon_graph")
      allow(Triannon::LdpLoader).to receive(:load).with(my_bookmark_anno.id).and_return(tg)
      fake_solr_hash = {:id => 'test'}
      allow(tg).to receive(:solr_hash).and_return(fake_solr_hash)
      expect(solr_writer).to receive(:add).with(fake_solr_hash)
      bookmark_anno.send(:solr_save)
    end
    it "raises exception when Solr add is not successful" do
      allow(solr_writer).to receive(:add).and_raise(RuntimeError)
      expect { bookmark_anno.send(:solr_save) }.to raise_error
    end
  end
  
  context '#solr_delete' do
    let(:solr_writer) { bookmark_anno.send(:solr_writer) }
    it "calls SolrWriter.delete with id" do
      expect(solr_writer).to receive(:delete).with(bookmark_anno.id)
      bookmark_anno.send(:solr_delete)
    end
    it "raises exception when Solr delete is not successful" do
      allow(solr_writer).to receive(:delete).and_raise(RuntimeError)
      expect { bookmark_anno.send(:solr_delete) }.to raise_error
    end
  end

  context '*find' do
    it "sets anno id" do
      anno = Triannon::Annotation.new({:data => Triannon.annotation_fixture("body-chars.ttl")})
      anno_id = anno.save
      my_anno = Triannon::Annotation.find(anno_id)
      expect(my_anno.id).to eq anno_id
    end
  end

  context "*all" do
    it "returns an array of all Annotation identifiers in the repository" do
      root_anno_ttl = File.read(Triannon.fixture_path("ldp_annotations") + '/fcrepo4_root_anno_container.ttl')
      allow_any_instance_of(Triannon::LdpLoader).to receive(:get_ttl).and_return(root_anno_ttl)
      results = Triannon::Annotation.all
      expect(results).to be_an_instance_of Array
      expect(results[0]).to be_an_instance_of Triannon::Annotation
      expect(results[0].id).to be_an_instance_of String
      # result only contains populated id attribute
      expect(results[0].id_as_url).to eql nil
    end
    it "calls LdpLoader.find_all" do
      expect_any_instance_of(Triannon::LdpLoader).to receive(:find_all)
      Triannon::Annotation.all
    end
  end

end
