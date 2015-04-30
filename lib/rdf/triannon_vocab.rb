require 'rdf'
module RDF
  # contains RDF predefined terms and properties for Triannon
  class Triannon < RDF::StrictVocabulary("http://triannon.stanford.edu/ns/")

    # Property definitions
    property :externalReference,
      comment: %(A reference to a resource external to Triannon storage.).freeze,
      label: "externalReference".freeze,
      "rdfs:isDefinedBy" => %(triannon:).freeze,
      range: "xsd:anyURI".freeze,  # rdf:URI?  rdfs:Resource?
      type: "rdf:Property".freeze
  end
end
