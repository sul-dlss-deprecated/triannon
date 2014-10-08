# Add new mime types for use in respond_to blocks:
Mime::Type.register "application/ld+json", :jsonld
Mime::Type.register "application/x-turtle", :ttl, ["text/turtle"]
Mime::Type.register "application/rdf+xml", :rdfxml, ["text/rdf+xml", "text/rdf"]
