require 'spec_helper'

describe "integration tests for Choice", :vcr do
  it "body is choice of ContentAsText" do
    target_url = "http://purl.stanford.edu/kq131cs7229"
    default_chars = "I love this Englishly!"
    item_chars = "Je l'aime en Francais!"
    write_anno = Triannon::Annotation.new data: "
    @prefix content: <http://www.w3.org/2011/content#> .
    @prefix dc11: <http://purl.org/dc/elements/1.1/> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    [
       a openannotation:Annotation;
       openannotation:hasBody [
         a openannotation:Choice;
         openannotation:default [
           a content:ContentAsText,
             dcmitype:Text;
           dc11:language \"en\";
           content:chars \"#{default_chars}\"
         ];
         openannotation:item [
           a content:ContentAsText,
             dcmitype:Text;
           dc11:language \"fr\";
           content:chars \"#{item_chars}\"
         ]
       ];
       openannotation:hasTarget <#{target_url}>;
       openannotation:motivatedBy openannotation:commenting
     ] ."
    g = write_anno.graph
    expect(g.size).to eql 15
    expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_blank_node = body_solns.first.object
    body_subj_node_solns = g.query [body_blank_node, nil, nil]
    expect(body_subj_node_solns.count).to eq 3
    expect(body_subj_node_solns).to include [body_blank_node, RDF.type, RDF::Vocab::OA.Choice]
    default_solns = g.query [body_blank_node, RDF::Vocab::OA.default, nil]
    expect(default_solns.count).to eq 1
    default_blank_node = default_solns.first.object
    item_solns = g.query [body_blank_node, RDF::Vocab::OA.item, nil]
    expect(item_solns.count).to eq 1
    item_blank_node = item_solns.first.object

    default_node_subject_solns = g.query [default_blank_node, nil, nil]
    expect(default_node_subject_solns.count).to eq 4
    expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
    expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
    expect(default_node_subject_solns).to include [default_blank_node, RDF::DC11.language, "en"]
    expect(default_node_subject_solns).to include [default_blank_node, RDF::Vocab::CNT.chars, default_chars]

    item_node_subject_solns = g.query [item_blank_node, nil, nil]
    expect(item_node_subject_solns.count).to eq 4
    expect(item_node_subject_solns).to include [item_blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
    expect(item_node_subject_solns).to include [item_blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
    expect(item_node_subject_solns).to include [item_blank_node, RDF::DC11.language, "fr"]
    expect(item_node_subject_solns).to include [item_blank_node, RDF::Vocab::CNT.chars, item_chars]

    sw = write_anno.send(:solr_writer)
    allow(sw).to receive(:add)
    id = write_anno.save

    anno = Triannon::Annotation.find id
    h = anno.graph
    expect(h.size).to eql g.size
    anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
    expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
    expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
    body_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, nil])
    expect(body_solns.size).to eql 1
    body_blank_node = body_solns.first.object
    body_subj_node_solns = h.query [body_blank_node, nil, nil]
    expect(body_subj_node_solns.count).to eq 3
    expect(body_subj_node_solns).to include [body_blank_node, RDF.type, RDF::Vocab::OA.Choice]
    default_solns = h.query [body_blank_node, RDF::Vocab::OA.default, nil]
    expect(default_solns.count).to eq 1
    default_blank_node = default_solns.first.object
    item_solns = h.query [body_blank_node, RDF::Vocab::OA.item, nil]
    expect(item_solns.count).to eq 1
    item_blank_node = item_solns.first.object

    default_node_subject_solns = h.query [default_blank_node, nil, nil]
    expect(default_node_subject_solns.count).to eq 4
    expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
    expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
    expect(default_node_subject_solns).to include [default_blank_node, RDF::DC11.language, "en"]
    expect(default_node_subject_solns).to include [default_blank_node, RDF::Vocab::CNT.chars, default_chars]

    item_node_subject_solns = h.query [item_blank_node, nil, nil]
    expect(item_node_subject_solns.count).to eq 4
    expect(item_node_subject_solns).to include [item_blank_node, RDF.type, RDF::Vocab::DCMIType.Text]
    expect(item_node_subject_solns).to include [item_blank_node, RDF.type, RDF::Vocab::CNT.ContentAsText]
    expect(item_node_subject_solns).to include [item_blank_node, RDF::DC11.language, "fr"]
    expect(item_node_subject_solns).to include [item_blank_node, RDF::Vocab::CNT.chars, item_chars]
  end
  it "body is choice of external URIs with addl metadata" do
    target_url = "http://purl.stanford.edu/kq131cs7229"
    body_default_uri = "http://www.myaudioblog.com/post/1.mp3"
    body_default_format = "audio/mpeg3"
    body_item_uri = "http://text.transcriptions.com"
    body_item_format = "text/plain"
    write_anno = Triannon::Annotation.new data: "
      @prefix openannotation: <http://www.w3.org/ns/oa#> .
      @prefix dc11: <http://purl.org/dc/elements/1.1/> .
      @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

       [
          a openannotation:Annotation;

          openannotation:hasTarget <#{target_url}>;
          openannotation:hasBody [
            a openannotation:Choice;
            openannotation:default <#{body_default_uri}>;
            openannotation:item <#{body_item_uri}>
          ];
          openannotation:motivatedBy openannotation:commenting
       ] .

       <#{body_default_uri}> a dcmitype:Sound;
           dc11:format \"#{body_default_format}\" .

       <#{body_item_uri}> a dcmitype:Text;
           dc11:format \"#{body_item_format}\" ."
     g = write_anno.graph
     expect(g.size).to eql 11
     expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
     body_solns = g.query([nil, RDF::Vocab::OA.hasBody, nil])
     expect(body_solns.size).to eql 1
     body_blank_node = body_solns.first.object
     body_subj_node_solns = g.query [body_blank_node, nil, nil]
     expect(body_subj_node_solns.count).to eq 3
     expect(body_subj_node_solns).to include [body_blank_node, RDF.type, RDF::Vocab::OA.Choice]

     default_uri_obj = RDF::URI.new(body_default_uri)
     expect(g.query([body_blank_node, RDF::Vocab::OA.default, default_uri_obj]).count).to eql 1
     default_solns = g.query [default_uri_obj, nil, nil]
     expect(default_solns.count).to eq 2
     expect(default_solns).to include [default_uri_obj, RDF.type, RDF::Vocab::DCMIType.Sound]
     expect(default_solns).to include [default_uri_obj, RDF::DC11.format, body_default_format]

     item_uri_obj = RDF::URI.new(body_item_uri)
     expect(g.query([body_blank_node, RDF::Vocab::OA.item, item_uri_obj]).count).to eql 1
     item_solns = g.query [item_uri_obj, nil, nil]
     expect(item_solns.count).to eq 2
     expect(item_solns).to include [item_uri_obj, RDF.type, RDF::Vocab::DCMIType.Text]
     expect(item_solns).to include [item_uri_obj, RDF::DC11.format, body_item_format]

     sw = write_anno.send(:solr_writer)
     allow(sw).to receive(:add)
     id = write_anno.save

     anno = Triannon::Annotation.find id
     h = anno.graph
     expect(h.size).to eql g.size
     anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
     expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasTarget, RDF::URI(target_url)]).size).to eql 1
     body_solns = h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, nil])
     expect(body_solns.size).to eql 1
     body_blank_node = body_solns.first.object
     body_subj_node_solns = h.query [body_blank_node, nil, nil]
     expect(body_subj_node_solns.count).to eq 3
     expect(body_subj_node_solns).to include [body_blank_node, RDF.type, RDF::Vocab::OA.Choice]

     expect(h.query([body_blank_node, RDF::Vocab::OA.default, default_uri_obj]).count).to eql 1
     default_solns = h.query [default_uri_obj, nil, nil]
     expect(default_solns.count).to eq 2
     expect(default_solns).to include [default_uri_obj, RDF.type, RDF::Vocab::DCMIType.Sound]
     expect(default_solns).to include [default_uri_obj, RDF::DC11.format, body_default_format]

     expect(h.query([body_blank_node, RDF::Vocab::OA.item, item_uri_obj]).count).to eql 1
     item_solns = h.query [item_uri_obj, nil, nil]
     expect(item_solns.count).to eq 2
     expect(item_solns).to include [item_uri_obj, RDF.type, RDF::Vocab::DCMIType.Text]
     expect(item_solns).to include [item_uri_obj, RDF::DC11.format, body_item_format]
  end
  it "target is choice of external URIs, default w addl metadata" do
    body_url = "http://dbpedia.org/resource/Otto_Ege"
    default_url = "http://some.external.ref/default"
    item_url = "http://some.external.ref/item"
    write_anno = Triannon::Annotation.new data: "
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

     [
        a openannotation:Annotation;

        openannotation:hasBody <#{body_url}>;
        openannotation:hasTarget [
          a openannotation:Choice;
          openannotation:default <#{default_url}>;
          openannotation:item <#{item_url}>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] .

     <#{default_url}> a dcmitype:Text ."
     g = write_anno.graph
     expect(g.size).to eql 8
     expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
     target_solns = g.query([nil, RDF::Vocab::OA.hasTarget, nil])
     expect(target_solns.size).to eql 1
     target_blank_node = target_solns.first.object
     target_subj_node_solns = g.query [target_blank_node, nil, nil]
     expect(target_subj_node_solns.count).to eq 3
     expect(target_subj_node_solns).to include [target_blank_node, RDF.type, RDF::Vocab::OA.Choice]
     default_solns = g.query [target_blank_node, RDF::Vocab::OA.default, nil]
     expect(default_solns.count).to eq 1
     default_blank_node = default_solns.first.object
     item_solns = g.query [target_blank_node, RDF::Vocab::OA.item, nil]
     expect(item_solns.count).to eq 1
     item_blank_node = item_solns.first.object

     default_node_subject_solns = g.query [default_blank_node, nil, nil]
     expect(default_node_subject_solns.count).to eq 1
     expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::DCMIType.Text]

     expect(g.query([item_blank_node, nil, nil]).count).to eq 0

     sw = write_anno.send(:solr_writer)
     allow(sw).to receive(:add)
     id = write_anno.save

     anno = Triannon::Annotation.find id
     h = anno.graph
     expect(h.size).to eql g.size
     anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
     expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
     target_solns = h.query([nil, RDF::Vocab::OA.hasTarget, nil])
     expect(target_solns.size).to eql 1
     target_blank_node = target_solns.first.object
     target_subj_node_solns = h.query [target_blank_node, nil, nil]
     expect(target_subj_node_solns.count).to eq 3
     expect(target_subj_node_solns).to include [target_blank_node, RDF.type, RDF::Vocab::OA.Choice]
     default_solns = h.query [target_blank_node, RDF::Vocab::OA.default, nil]
     expect(default_solns.count).to eq 1
     default_blank_node = default_solns.first.object
     item_solns = h.query [target_blank_node, RDF::Vocab::OA.item, nil]
     expect(item_solns.count).to eq 1
     item_blank_node = item_solns.first.object

     default_node_subject_solns = h.query [default_blank_node, nil, nil]
     expect(default_node_subject_solns.count).to eq 1
     expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::DCMIType.Text]

     expect(h.query([item_blank_node, nil, nil]).count).to eq 0
  end
  it "target is choice of three images URIs" do
    body_url = "http://dbpedia.org/resource/Otto_Ege"
    default_url = "http://images.com/small"
    item1_url = "http://images.com/large"
    item2_url = "http://images.com/huge"
    write_anno = Triannon::Annotation.new data: "
    @prefix openannotation: <http://www.w3.org/ns/oa#> .
    @prefix dcmitype: <http://purl.org/dc/dcmitype/> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

     [
        a openannotation:Annotation;

        openannotation:hasBody <#{body_url}>;
        openannotation:hasTarget [
          a openannotation:Choice;
          openannotation:default <#{default_url}>;
          openannotation:item <#{item1_url}>;
          openannotation:item <#{item2_url}>
        ];
        openannotation:motivatedBy openannotation:commenting
     ] .

     <#{default_url}> a dcmitype:Image .

     <#{item1_url}> a dcmitype:Image .

     <#{item2_url}> a dcmitype:Image ."

     g = write_anno.graph
     expect(g.size).to eql 11
     expect(g.query([nil, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
     expect(g.query([nil, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
     target_solns = g.query([nil, RDF::Vocab::OA.hasTarget, nil])
     expect(target_solns.size).to eql 1
     target_blank_node = target_solns.first.object
     target_subj_node_solns = g.query [target_blank_node, nil, nil]
     expect(target_subj_node_solns.count).to eq 4
     expect(target_subj_node_solns).to include [target_blank_node, RDF.type, RDF::Vocab::OA.Choice]
     default_solns = g.query [target_blank_node, RDF::Vocab::OA.default, nil]
     expect(default_solns.count).to eq 1
     default_blank_node = default_solns.first.object
     item_solns = g.query [target_blank_node, RDF::Vocab::OA.item, nil]
     expect(item_solns.count).to eq 2
     item1_blank_node = item_solns.first.object
     item2_blank_node = item_solns.to_a[1].object

     default_node_subject_solns = g.query [default_blank_node, nil, nil]
     expect(default_node_subject_solns.count).to eq 1
     expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::DCMIType.Image]
     item1_subject_solns = g.query [item1_blank_node, nil, nil]
     expect(item1_subject_solns.count).to eq 1
     expect(item1_subject_solns).to include [item1_blank_node, RDF.type, RDF::Vocab::DCMIType.Image]
     item2_subject_solns = g.query [item2_blank_node, nil, nil]
     expect(item2_subject_solns.count).to eq 1
     expect(item2_subject_solns).to include [item2_blank_node, RDF.type, RDF::Vocab::DCMIType.Image]

     sw = write_anno.send(:solr_writer)
     allow(sw).to receive(:add)
     id = write_anno.save

     anno = Triannon::Annotation.find id
     h = anno.graph
     expect(h.size).to eql g.size
     anno_uri_obj = RDF::URI.new("#{Triannon.config[:triannon_base_url]}/#{id}")
     expect(h.query([anno_uri_obj, RDF.type, RDF::Vocab::OA.Annotation]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.motivatedBy, RDF::Vocab::OA.commenting]).size).to eql 1
     expect(h.query([anno_uri_obj, RDF::Vocab::OA.hasBody, RDF::URI(body_url)]).size).to eql 1
     target_solns = h.query([nil, RDF::Vocab::OA.hasTarget, nil])
     expect(target_solns.size).to eql 1
     target_blank_node = target_solns.first.object
     target_subj_node_solns = h.query [target_blank_node, nil, nil]
     expect(target_subj_node_solns.count).to eq 4
     expect(target_subj_node_solns).to include [target_blank_node, RDF.type, RDF::Vocab::OA.Choice]
     default_solns = h.query [target_blank_node, RDF::Vocab::OA.default, nil]
     expect(default_solns.count).to eq 1
     default_blank_node = default_solns.first.object
     item_solns = h.query [target_blank_node, RDF::Vocab::OA.item, nil]
     expect(item_solns.count).to eq 2
     item1_blank_node = item_solns.first.object
     item2_blank_node = item_solns.to_a[1].object

     default_node_subject_solns = h.query [default_blank_node, nil, nil]
     expect(default_node_subject_solns.count).to eq 1
     expect(default_node_subject_solns).to include [default_blank_node, RDF.type, RDF::Vocab::DCMIType.Image]
     item1_subject_solns = g.query [item1_blank_node, nil, nil]
     expect(item1_subject_solns.count).to eq 1
     expect(item1_subject_solns).to include [item1_blank_node, RDF.type, RDF::Vocab::DCMIType.Image]
     item2_subject_solns = g.query [item2_blank_node, nil, nil]
     expect(item2_subject_solns.count).to eq 1
     expect(item2_subject_solns).to include [item2_blank_node, RDF.type, RDF::Vocab::DCMIType.Image]
  end
  it "Choice as object of hasSelector" do
    skip 'need to implement Choice for hasSelector (does this test belong in SpecificResource?)'
  end

end
