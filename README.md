[![Build Status](https://travis-ci.org/sul-dlss/triannon.svg?branch=master)](https://travis-ci.org/sul-dlss/triannon) [![Coverage Status](https://coveralls.io/repos/sul-dlss/triannon/badge.png)](https://coveralls.io/r/sul-dlss/triannon) [![Dependency Status](https://gemnasium.com/sul-dlss/triannon.svg)](https://gemnasium.com/sul-dlss/triannon) [![Gem Version](https://badge.fury.io/rb/triannon.svg)](http://badge.fury.io/rb/triannon)

# Triannon

Store Open Annotation in Fedora4 to support the Linked Data for Libraries use cases.

## Tests

Run tests:

```console
$ rake
```

## Installation

Add this line to your gemfile

```ruby
gem 'triannon'
```

Then execute:

```console
$ bundle
```

Then run the triannon generator:

```console
$ rails g triannon:install
```

Edit the `config/triannon.yml` file:

* `ldp_url:` Points to the root annotations container on your LDP server
* `solr_url:` Points to the baseurl of Solr instance configured for Triannon
* `triannon_base_url:` Used as the base url for all annotations hosted by your Triannon server.  Identifiers from the LDP server will be appended to this base-url.  Generally something like "https://your-triannon-rails-box/annotations", as "/annotations" is added to the path by the Triannon gem

Generate the root annotations container on the LDP server

```console
$ rake triannon:create_root_container
```

# Client Interactions with Triannon

### Get a list of annos
NOTE:  implementation of Annotation Lists is coming!
GET: http://(host)/
GET: http://(host)/annotations

### Get a particular anno
GET: http://(host)/annotations/(anno_id)
* use HTTP Accept header with mime type to indicate desired format
** default:  jsonld
*** indicate desired context url in the HTTP Accept header thus:
**** Accept: application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"
**** Accept: application/ld+json; profile="http://iiif.io/api/presentation/2/context.json"

** also supports turtle, rdfxml, json, html
*** indicated desired context url for jsonld as json in the HTTP Link header thus:
**** Accept: application/json
**** Link: http://www.w3.org/ns/oa.json; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"
***** note that the "type" part is optional and refers to the type of the rel, which is the reference for all json-ld contexts.
** see https://github.com/sul-dlss/triannon/blob/master/app/controllers/triannon/annotations_controller.rb #show method for mime formats accepted

#### JSON-LD context
You can request IIIF or OA context for jsonld.  

The correct way:
GET: http://(host)/annotations/(anno_id)
* use HTTP Accept header with mime type and context url:
** Accept: application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"
** Accept: application/ld+json; profile="http://iiif.io/api/presentation/2/context.json"

You can also use either of these methods (with the correct HTTP Accept header):

GET: http://(host)/annotations/iiif/(anno_id)
GET: http://(host)/annotations/(anno_id)?jsonld_context=iiif

GET: http://(host)/annotations/oa/(anno_id)
GET: http://(host)/annotations/(anno_id)?jsonld_context=oa

Note that OA (Open Annotation) is the default context if none is specified.

### Create an anno
POST: http://(host)/annotations
* the body of the HTTP request should contain the annotation, as jsonld, turtle, or rdfxml
* the Content-Type header should be the mime type matching the body
* the anno to be created should NOT already have an assigned @id
* to get a particular format back, use the HTTP Accept header
** to get a particular context for jsonld, do one of the following:
**** Accept: application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"
**** Accept: application/ld+json; profile="http://iiif.io/api/presentation/2/context.json"
** to get a particular jsonld context for jsonld as json, specify it in the HTTP Link header thus:
**** Accept: application/json
**** Link: http://www.w3.org/ns/oa.json; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"
***** note that the "type" part is optional and refers to the type of the rel, which is the reference for all json-ld contexts.

### Delete an anno
DELETE: http://(host)/annotations/(anno_id)


## Running the application in development

There is a bundled rake task for running the test app, but there is some one-time set up.

### One time setup

##### Set up a local instance of Fedora4
```console
$ rake jetty:download
$ rake jetty:unzip
```
##### Set up a Triannon flavored Solr
```console
rake triannon:solr_jetty_setup
```

##### Set up a runnable Rails app that uses triannon gem
```console
$ rake engine_cart:generate # (first run only)
```

##### Configure spec/internal/config/triannon.yml as specified above
```console
$ vi spec/internal/config/triannon.yml
```

##### Generate root annotations container
```console
$ rake triannon:create_root_container
```

# Run the test app
```console
$ rake jetty:start
$ rake triannon:server
$ rake jetty:stop # at some point
```
