require 'spec_helper'

describe Triannon::Graph, :vcr do
  
  let(:g1) { Triannon::Graph.new RDF::Graph.new.from_ttl("
    <http://my.identifiers.com/oa_comment> a <http://www.w3.org/ns/oa#Annotation>;
       <http://www.w3.org/ns/oa#hasBody> [
         a <http://www.w3.org/2011/content#ContentAsText>,
           <http://purl.org/dc/dcmitype/Text>;
         <http://www.w3.org/2011/content#chars> \"I love this!\"
       ];
       <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>;
       <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#commenting> . ") }
  let(:g2) { Triannon::Graph.new RDF::Graph.new.from_jsonld(
    '{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
        "@id": "http://my.identifiers.com/oa_bookmark",
        "@type": "oa:Annotation", 
        "motivatedBy": "oa:bookmarking", 
        "hasTarget": "http://purl.stanford.edu/kq131cs7229"
      }' ) }
  let(:g3) {Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-targets.json")}
  
  context 'jsonld flavors' do
    context '#jsonld_oa' do
      it 'has context as url' do
        expect(g1.jsonld_oa).to match /"@context":\s*"http:\/\/www.w3.org\/ns\/oa.jsonld"/
        expect(g2.jsonld_oa).to match /"@context":\s*"http:\/\/www.w3.org\/ns\/oa.jsonld"/
      end
      it 'parses as graph' do
        new_g = Triannon::Graph.new RDF::Graph.new.from_jsonld g1.jsonld_oa
        expect(new_g.to_ttl).to eq g1.to_ttl
        new_g = Triannon::Graph.new RDF::Graph.new.from_jsonld g2.jsonld_oa
        expect(new_g.to_ttl).to eq g2.to_ttl
      end
    end
    context '#jsonld_iiif' do
      it 'has context as url' do
        expect(g1.jsonld_iiif).to match /"@context":\s*"http:\/\/iiif.io\/api\/presentation\/2\/context.json"/
        expect(g2.jsonld_iiif).to match /"@context":\s*"http:\/\/iiif.io\/api\/presentation\/2\/context.json"/
      end
      it 'parses as graph' do
        new_g = Triannon::Graph.new RDF::Graph.new.from_jsonld g1.jsonld_iiif
        expect(new_g.to_ttl).to eq g1.to_ttl
        new_g = Triannon::Graph.new RDF::Graph.new.from_jsonld g2.jsonld_iiif
        expect(new_g.to_ttl).to eq g2.to_ttl
      end
    end
  end

  context 'solr_hash' do
    let(:uuid) {"814b0225-bd48-4de9-a724-a72a9fa86c18"}
    let(:base_url) {"https://triannon-dev.stanford.edu/annotations/"}
    let(:tg) {Triannon::Graph.new RDF::Graph.new.from_ttl "
     <#{base_url}#{uuid}> a <http://www.w3.org/ns/oa#Annotation>;
       <http://www.w3.org/ns/oa#annotatedAt> \"2015-01-07T18:01:21Z\"^^<http://www.w3.org/2001/XMLSchema#dateTime>;
       <http://www.w3.org/ns/oa#hasBody> [
         a <http://purl.org/dc/dcmitype/Text>,
           <http://www.w3.org/2011/content#ContentAsText>;
         <http://purl.org/dc/terms/format> \"text/plain\";
         <http://www.w3.org/2011/content#chars> \"blah blah\"
       ];
       <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666>;
       <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#tagging> ." }
    let(:tg_solr_hash) { 
      config = { :triannon_base_url => base_url }
      allow(Triannon).to receive(:config).and_return(config)
      tg.solr_hash 
    }
    
    context 'id' do
      it "is a String" do
        expect(tg_solr_hash[:id]).to be_a String
      end
      it "only the uuid, not the full url" do
        expect(tg_solr_hash[:id]).to eq uuid
      end
      it "slash not part of base_url" do
        config = { :triannon_base_url =>  "https://triannon-dev.stanford.edu/annotations" }
        allow(Triannon).to receive(:config).and_return(config)
        my_tg = Triannon::Graph.new RDF::Graph.new.from_ttl "
         <#{base_url}/#{uuid}> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666>;
           <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#tagging> ." 
        expect(tg.solr_hash[:id]).to eq uuid
      end
      it "slash part of base_url" do
        # see 'only the uuid, not the full url'
      end
      it "calls id_as_url" do
        expect(tg).to receive(:id_as_url).and_call_original
        tg.solr_hash
      end
    end
    
    context 'motivation' do
      it "is an Array" do
        expect(tg_solr_hash[:motivation]).to be_an Array
      end
      it "calls motivated_by" do
        expect(tg).to receive(:motivated_by).and_call_original
        tg.solr_hash
      end
      it "uses short Strings, not the full urls" do
        expect(tg_solr_hash[:motivation]).to eq ["tagging"]
      end
    end
    
    context 'annotated_at' do
      it "is a String" do
        expect(tg_solr_hash[:annotated_at]).to be_a String
      end
      it "format accepted by Solr for date field" do
        # date field format: 1995-12-31T23:59:59Z; or w fractional seconds: 1995-12-31T23:59:59.999Z
        expect(tg_solr_hash[:annotated_at]).to eq "2015-01-07T18:01:21Z"
      end
      it "calls annotated_at" do
        expect(tg).to receive(:annotated_at)
        tg.solr_hash
      end
      it "calls Time.parse" do
        expect(Time).to receive(:parse)
        tg.solr_hash
      end
      it "nil if date won't parse cleanly" do
        my_tg = Triannon::Graph.new RDF::Graph.new.from_ttl "
         <https://sul-fedora-dev-a.stanford.edu/fedora/rest/anno/f3bc7da9-d531-4b0c-816a-8f2fc849b0b6> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#annotatedAt> \"not a date\" ." 
        expect(my_tg.solr_hash[:annotated_at]).to eq nil
      end
    end
    
    context 'target_url' do
      it "is an Array of urls as Strings" do
        expect(tg_solr_hash[:target_url]).to be_an Array
        expect(tg_solr_hash[:target_url].first).to be_a String
        expect(tg_solr_hash[:target_url].first).to match /^http/
      end
      it "calls predicate_urls with hasTarget" do
        allow(tg).to receive(:predicate_urls).with(RDF::OpenAnnotation.hasBody).and_call_original
        expect(tg).to receive(:predicate_urls).with(RDF::OpenAnnotation.hasTarget).and_call_original
        tg.solr_hash
      end
      it "is empty array if no target is a url" do
        my_g = Triannon::Graph.new RDF::Graph.new.from_ttl Triannon.annotation_fixture("target-choice.ttl")
        expect(my_g.solr_hash[:target_url]).to eq []
      end
    end
    context 'target_type' do
      # TODO: recognize more target types
      it "is an Array with 'external_URI' if a target is a url" do
        expect(tg_solr_hash[:target_type]).to be_an Array
        expect(tg_solr_hash[:target_type].first).to be_a String
        expect(tg_solr_hash[:target_type].first).to eq 'external_URI'
      end
      it "has external_URI once if multiple targets" do
        expect(g3.solr_hash[:target_type]).to eq ['external_URI']
      end
      it "is nil if no target is a url" do
        my_g = Triannon::Graph.new RDF::Graph.new.from_ttl Triannon.annotation_fixture("target-choice.ttl")
        expect(my_g.solr_hash[:target_type]).to be nil
      end
    end
    
    context 'body_url' do
      it "is an Array of urls as Strings" do
        my_g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-url.json")
        my_body_urls = my_g.solr_hash[:body_url]
        expect(my_body_urls).to be_an Array
        expect(my_body_urls.first).to be_a String
        expect(my_body_urls.first).to match /^http/
      end
      it "calls predicate_urls with hasBody" do
        allow(tg).to receive(:predicate_urls).with(RDF::OpenAnnotation.hasTarget).and_call_original
        expect(tg).to receive(:predicate_urls).with(RDF::OpenAnnotation.hasBody).and_call_original
        tg.solr_hash
      end
      it "is empty array if no bodies are urls" do
        expect(tg_solr_hash[:body_url]).to eq []
      end
    end
    context 'body_chars_exact' do
      it "is an Array of Strings" do
        my_body_chars = tg_solr_hash[:body_chars_exact]
        expect(my_body_chars).to be_an Array
        expect(my_body_chars.first).to be_a String
        expect(my_body_chars.first).to eq 'blah blah'
      end
      it "calls body_chars" do
        expect(tg).to receive(:body_chars).and_call_original
        tg.solr_hash
      end
      it "strips the Strings" do
        my_ttl = "
         <#{base_url}#{uuid}> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#hasBody> [
             a <http://purl.org/dc/dcmitype/Text>,
               <http://www.w3.org/2011/content#ContentAsText>;
             <http://purl.org/dc/terms/format> \"text/plain\";
             <http://www.w3.org/2011/content#chars> \"  spaces  \"
           ];
           <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666>;
           <http://www.w3.org/ns/oa#motivatedBy> <http://www.w3.org/ns/oa#tagging> ."
        my_tg = Triannon::Graph.new RDF::Graph.new.from_ttl my_ttl
        expect(my_tg.solr_hash[:body_chars_exact]).to eq ['spaces']
      end
      it "empty Array if no bodies are contentAsText" do
        my_g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-url.json")
        expect(my_g.solr_hash[:body_chars_exact]).to eq []
      end
    end
    context 'body_type' do
      it "is an Array with 'external_URI' if a body is a url" do
        my_g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-url.json")
        expect(my_g.solr_hash[:body_type]).to be_an Array
        expect(my_g.solr_hash[:body_type].first).to be_a String
        expect(my_g.solr_hash[:body_type].first).to eq 'external_URI'
      end
      it "includes content_as_text if a body is as such" do
        expect(tg_solr_hash[:body_type]).to eq ['content_as_text']
      end
      it "has all types represented by multiple bodies" do
        my_g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-bodies.json")
        my_body_types = my_g.solr_hash[:body_type]
        expect(my_body_types.size).to eq 2
        expect(my_body_types).to include 'external_URI'
        expect(my_body_types).to include 'content_as_text'
      end
      it "is 'no_body' if there is no body" do
        expect(g2.solr_hash[:body_type]).to eq ['no_body']
      end
    end
    
    context 'anno_jsonld' do
      it "is a String" do
        expect(tg_solr_hash[:anno_jsonld]).to be_a String
      end
      it "calls jsonld_oa" do
        expect(tg).to receive(:jsonld_oa)
        tg.solr_hash
      end
      it "is entire anno as jsonld" do
        my_tg = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-bodies.json")
        expect(my_tg.solr_hash[:anno_jsonld]).to eq my_tg.jsonld_oa
      end
      it "has OA context" do
        my_tg = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-chars-plain-iiif.json")
        expect(my_tg.solr_hash[:anno_jsonld]).to match Triannon::JsonldContext::OA_CONTEXT_URL
        expect(my_tg.solr_hash[:anno_jsonld]).not_to match Triannon::JsonldContext::IIIF_CONTEXT_URL
        my_tg = Triannon::Graph.new RDF::Graph.new.from_ttl Triannon.annotation_fixture("body-chars.ttl")
        expect(my_tg.solr_hash[:anno_jsonld]).to match Triannon::JsonldContext::OA_CONTEXT_URL
      end
      it "has non-empty id value for outer node" do
        expect(tg_solr_hash[:anno_jsonld]).not_to match "@id\":\"\""
        expect(tg_solr_hash[:anno_jsonld]).to match "@id\":\".+\""
      end
    end
  end # solr_hash

  context "canned query methods" do
    it "#id_as_url" do
      expect(g1.id_as_url).to eql("http://my.identifiers.com/oa_comment")
      expect(g2.id_as_url).to eql("http://my.identifiers.com/oa_bookmark")
      expect(g3.id_as_url).to eql("http://example.org/annos/annotation/mult-targets.json")
    end
    context "#motivated_by" do
      it "single" do
        expect(g1.motivated_by).to eq ["http://www.w3.org/ns/oa#commenting"]
        expect(g2.motivated_by).to eq ["http://www.w3.org/ns/oa#bookmarking"]
        expect(g3.motivated_by).to eq ["http://www.w3.org/ns/oa#commenting"]
      end
      it "multiple" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-motivations.json")
        gm = g.motivated_by
        expect(gm.size).to eql 2
        expect(gm).to include("http://www.w3.org/ns/oa#moderating")
        expect(gm).to include("http://www.w3.org/ns/oa#tagging")
      end
      it "missing: empty Array" do
        my_tg = Triannon::Graph.new RDF::Graph.new.from_ttl "
         <https://sul-fedora-dev-a.stanford.edu/fedora/rest/anno/f3bc7da9-d531-4b0c-816a-8f2fc849b0b6> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#hasTarget> <http://searchworks.stanford.edu/view/666> ." 
        expect(my_tg.motivated_by).to eq []
      end
    end
    context '#predicate_urls' do
      it "single" do
        expect(g2.predicate_urls(RDF::OpenAnnotation.hasTarget)).to eq ["http://purl.stanford.edu/kq131cs7229"]
      end
      it "multiple" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-targets.json")
        gu = g.predicate_urls(RDF::OpenAnnotation.hasTarget)
        expect(gu.size).to eql 2
        expect(gu).to include("http://purl.stanford.edu/kq131cs7229")
        expect(gu).to include("https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg")
      end
      it "none" do
        expect(g2.predicate_urls(RDF::OpenAnnotation.hasBody)).to eq []
      end
      it "not a url" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-chars.json")
        expect(g.predicate_urls(RDF::OpenAnnotation.hasBody)).to eq []
      end
    end
    context '#body_chars' do
      it "single" do
        expect(g1.body_chars).to eq ["I love this!"]
      end
      it "multiple" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld '
        {
          "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
          "@type": "oa:Annotation", 
          "motivatedBy": [
            "oa:tagging"
          ], 
          "hasBody": [
            {
              "@type": [
                "cnt:ContentAsText"
              ], 
              "chars": "I love this!"
            }, 
            {
              "@type": [
                "cnt:ContentAsText"
              ], 
              "chars": "me too"
            }
          ],
          "hasTarget": "http://purl.stanford.edu/kq131cs7229"
        }'
        gbc = g.body_chars
        expect(gbc.size).to eql 2
        expect(gbc).to include "I love this!"
        expect(gbc).to include "me too"
      end
      it "multiple bodies, but only one has chars" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("mult-bodies.json")
        expect(g.body_chars).to eq ["I love this!"]
      end
      it "whitespace retained at beginning or ending" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld '
        {
          "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
          "@type": "oa:Annotation", 
          "motivatedBy": [
            "oa:tagging"
          ], 
          "hasBody": [
            {
              "@type": [
                "cnt:ContentAsText"
              ], 
              "chars": "  la  "
            }
          ],
          "hasTarget": "http://purl.stanford.edu/kq131cs7229"
        }'
        expect(g.body_chars).to eq ["  la  "]
      end
      it "chars is empty string" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld '
        {
          "@context": "http://www.w3.org/ns/oa-context-20130208.json", 
          "@type": "oa:Annotation", 
          "motivatedBy": [
            "oa:tagging"
          ], 
          "hasBody": [
            {
              "@type": [
                "cnt:ContentAsText"
              ], 
              "chars": ""
            }
          ],
          "hasTarget": "http://purl.stanford.edu/kq131cs7229"
        }'
        expect(g.body_chars).to eq [""]
      end
      it "body is a url" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("body-pdf.json")
        expect(g.body_chars).to eq []
      end
    end
    context '#annotated_at' do
      it "String if present" do
        g = Triannon::Graph.new RDF::Graph.new.from_jsonld Triannon.annotation_fixture("provenance.json")
        expect(g.annotated_at).to eq "2014-09-03T17:16:13Z"
      end
      it "nil if absent" do
        expect(g1.annotated_at).to be nil
      end
    end
  end # canned query methods

  context '#remove_non_base_statements' do
    it 'calls #remove_has_target_statements' do
      g = Triannon::Graph.new(RDF::Graph.new)
      expect(g).to receive(:remove_has_target_statements)
      allow(g).to receive(:remove_has_body_statements)
      g.remove_non_base_statements
    end
    it 'calls #remove_has_body_statements' do
      g = Triannon::Graph.new(RDF::Graph.new)
      expect(g).to receive(:remove_has_body_statements)
      allow(g).to receive(:remove_has_target_statements).and_return(g)
      g.remove_non_base_statements
    end
  end
  
  context '#remove_has_body_statements' do
    it 'calls remove_predicate_and_its_object_statements with RDF::OpenAnnotation.hasBody' do
      g = Triannon::Graph.new(RDF::Graph.new)
      expect(g).to receive(:remove_predicate_and_its_object_statements).with(RDF::OpenAnnotation.hasBody)
      g.remove_has_body_statements
    end
  end

  context '#remove_has_target_statements' do
    it 'calls remove_predicate_and_its_object_statements with RDF::OpenAnnotation.hasTarget' do
      g = Triannon::Graph.new(RDF::Graph.new)
      expect(g).to receive(:remove_predicate_and_its_object_statements).with(RDF::OpenAnnotation.hasTarget)
      g.remove_has_target_statements
    end
  end
  
  context '#remove_predicate_and_its_object_statements' do
    it 'calls *subject_statements for each object of predicate statement' do
      g = Triannon::Graph.new(RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": [
          "http://target.one.org",
          "http://target.two.org"
        ]
      }'))
      expect(Triannon::Graph).to receive(:subject_statements).with(RDF::URI.new("http://target.one.org"), anything)
      expect(Triannon::Graph).to receive(:subject_statements).with(RDF::URI.new("http://target.two.org"), anything)
      g.remove_predicate_and_its_object_statements(RDF::OpenAnnotation.hasTarget)
    end
    it 'removes each predicate statement' do
      g = Triannon::Graph.new(RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "motivatedBy": "oa:commenting",
        "hasTarget": [
          "http://target.one.org",
          {
            "@id": "http://dbpedia.org/resource/Love", 
            "@type": "oa:SemanticTag"
          }
        ]
      }'))
      pred_stmts = g.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      
      pred_stmts.each { |s| 
        expect_any_instance_of(RDF::Graph).to receive(:delete).with(s)
      }
      allow(Triannon::Graph).to receive(:subject_statements).and_return([])
      g.remove_predicate_and_its_object_statements(RDF::OpenAnnotation.hasTarget)
    end
    it "removes each statement about the predicate statement's object" do
      g = Triannon::Graph.new(RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "@type": "oa:Annotation",
        "motivatedBy": "oa:commenting",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSelector": {
            "@type": "oa:FragmentSelector",
            "value": "xywh=0,0,200,200",
            "conformsTo": "http://www.w3.org/TR/media-frags/"
          }
        }
      }'))
      expect(g.size).to eql 8
      pred_stmts = g.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      pred_obj = pred_stmts.first.object
      sub_stmts = Triannon::Graph.subject_statements(pred_obj, g)
      expect(sub_stmts.size).to eql 5
      sub_stmts.each { |s|  
        expect_any_instance_of(RDF::Graph).to receive(:delete).with(s).and_call_original
      }
      allow_any_instance_of(RDF::Graph).to receive(:delete).with(pred_stmts.first).and_call_original
      g.remove_predicate_and_its_object_statements(RDF::OpenAnnotation.hasTarget)
      expect(g.size).to eql 2
    end
  end
  
  context '#make_null_relative_uri_out_of_blank_node' do
    it 'outer blank node becomes null relative uri' do
      g = RDF::Graph.new.from_ttl('[ 
      a <http://www.w3.org/ns/oa#Annotation>;
      <http://www.w3.org/ns/oa#hasBody> [
        a <http://www.w3.org/2011/content#ContentAsText>,
          <http://purl.org/dc/dcmitype/Text>;
        <http://www.w3.org/2011/content#chars> "I love this!"
        ]
      ] .')
      orig_size = g.size
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      expect(anno_stmts.size).to eql 1
      anno_rdf_obj = anno_stmts.first.subject
      expect(anno_rdf_obj).to be_a(RDF::Node)
      g = Triannon::Graph.new(g)
      g.make_null_relative_uri_out_of_blank_node
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      expect(anno_stmts.size).to eql 1
      anno_rdf_obj = anno_stmts.first.subject
      expect(anno_rdf_obj).to be_a(RDF::URI)
      expect(g.size).to eql orig_size
    end
    it 'null relative uri is left alone' do
      g = RDF::Graph.new.from_ttl('<> a <http://www.w3.org/ns/oa#Annotation>;
      <http://www.w3.org/ns/oa#hasBody> [
        a <http://www.w3.org/2011/content#ContentAsText>,
          <http://purl.org/dc/dcmitype/Text>;
        <http://www.w3.org/2011/content#chars> "I love this!"
        ] .')
      orig_size = g.size
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      expect(anno_stmts.size).to eql 1
      anno_rdf_obj = anno_stmts.first.subject
      expect(anno_rdf_obj).to be_a(RDF::URI)
      g = Triannon::Graph.new(g)
      g.make_null_relative_uri_out_of_blank_node
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      expect(anno_stmts.size).to eql 1
      anno_rdf_obj = anno_stmts.first.subject
      expect(anno_rdf_obj).to be_a(RDF::URI)
      expect(g.size).to eql orig_size
    end
  end
  
  context '*subject_statements' do
    it 'returns appropriate blank node statements when the subject is an RDF::Node in the graph' do
      graph = RDF::Graph.new.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasBody> [
           a <http://www.w3.org/2011/content#ContentAsText>,
             <http://purl.org/dc/dcmitype/Text>;
           <http://www.w3.org/2011/content#chars> "I love this!"
         ] .')
      body_resource = graph.query([nil, RDF::OpenAnnotation.hasBody, nil]).first.object
      body_stmts = Triannon::Graph.subject_statements(body_resource, graph)
      expect(body_stmts.size).to eql 3
      expect(body_stmts).to include([body_resource, RDF::Content::chars, "I love this!"])
      expect(body_stmts).to include([body_resource, RDF.type, RDF::Content.ContentAsText])
      expect(body_stmts).to include([body_resource, RDF.type, RDF::DCMIType.Text])
    end
    it 'recurses to get triples from objects of the subject statements' do
      graph = RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSource": "http://purl.stanford.edu/kq131cs7229.html",
          "hasSelector": {
            "@type": "oa:TextPositionSelector",
            "start": 0,
            "end": 66
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::Graph.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 6
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, "http://purl.stanford.edu/kq131cs7229.html"])
      selector_resource =  graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource])
      expect(target_stmts).to include([selector_resource, RDF.type, RDF::OpenAnnotation.TextPositionSelector])
      expect(target_stmts).to include([selector_resource, RDF::OpenAnnotation.start, RDF::Literal.new(0)])
      expect(target_stmts).to include([selector_resource, RDF::OpenAnnotation.end, RDF::Literal.new(66)])

      graph = RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSelector": {
            "@type": "oa:FragmentSelector",
            "value": "xywh=0,0,200,200",
            "conformsTo": "http://www.w3.org/TR/media-frags/"
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::Graph.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 5
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      selector_resource =  graph.query([target_resource, RDF::OpenAnnotation.hasSelector, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSelector, selector_resource])
      expect(target_stmts).to include([selector_resource, RDF.type, RDF::OpenAnnotation.FragmentSelector])
      expect(target_stmts).to include([selector_resource, RDF.value, RDF::Literal.new("xywh=0,0,200,200")])
      expect(target_stmts).to include([selector_resource, RDF::DC.conformsTo, "http://www.w3.org/TR/media-frags/"])
    end
    it 'finds all properties of URI nodes' do
      graph = RDF::Graph.new.from_jsonld('{
        "@context": "http://www.w3.org/ns/oa-context-20130208.json",
        "hasTarget": {
          "@type": "oa:SpecificResource",
          "hasSource": {
            "@id": "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg",
            "@type": "dctypes:Image"
          }
        }
      }')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      target_stmts = Triannon::Graph.subject_statements(target_resource, graph)
      expect(target_stmts.size).to eql 3
      expect(target_stmts).to include([target_resource, RDF.type, RDF::OpenAnnotation.SpecificResource])
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, "https://stacks.stanford.edu/image/kq131cs7229/kq131cs7229_05_0032_large.jpg"])
      source_resource = graph.query([target_resource, RDF::OpenAnnotation.hasSource, nil]).first.object
      expect(target_stmts).to include([target_resource, RDF::OpenAnnotation.hasSource, source_resource])
      expect(target_stmts).to include([source_resource, RDF.type, RDF::DCMIType.Image])
    end
    it 'empty Array when the subject is not in the graph' do
      graph = RDF::Graph.new.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasBody> [
           a <http://www.w3.org/2011/content#ContentAsText>,
             <http://purl.org/dc/dcmitype/Text>;
           <http://www.w3.org/2011/content#chars> "I love this!"
         ] .')
      expect(Triannon::Graph.subject_statements(RDF::Node.new, graph)).to eql []
      expect(Triannon::Graph.subject_statements(RDF::URI.new("http://not.there.org"), graph)).to eql []
    end
    it 'empty Array when the subject is an RDF::URI with no additional properties' do
      graph = RDF::Graph.new.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>.')
      target_resource = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil]).first.object
      expect(target_resource).to be_a RDF::URI
      expect(Triannon::Graph.subject_statements(target_resource, graph)).to eql []
    end
    it 'empty Array when subject is not RDF::Node or RDF::URI' do
      graph = RDF::Graph.new.from_ttl('<http://example.org/annos/annotation/body-chars.ttl> <http://www.w3.org/ns/oa#hasTarget> <http://purl.stanford.edu/kq131cs7229>.')
      expect(Triannon::Graph.subject_statements(RDF.type, graph)).to eql []
    end
  end # *subject_statements

  context '*anno_query' do
    it "should find a solution when graph has RDF.type OA::Annotation" do
      my_url = "http://fakeurl.org/id"
      g = RDF::Graph.new.from_ttl("<#{my_url}> a <http://www.w3.org/ns/oa#Annotation> .")
      solutions = g.query Triannon::Graph.anno_query
      expect(solutions.size).to eq 1
      expect(solutions.first.s.to_s).to eq my_url
    end
    it "should not find a solution when graph has no RDF.type OA::Annotation" do
      g = RDF::Graph.new.from_ttl("<http://anywehre.com> a <http://foo.org/thing> .")
      solutions = g.query Triannon::Graph.anno_query
      expect(solutions.size).to eq 0
    end
    it "doesn't find solution when graph is empty" do
      solutions = RDF::Graph.new.query Triannon::Graph.anno_query
      expect(solutions.size).to eq 0
    end
  end

end