[![Build Status](https://travis-ci.org/sul-dlss/triannon.svg?branch=master)](https://travis-ci.org/sul-dlss/triannon) [![Coverage Status](https://coveralls.io/repos/sul-dlss/triannon/badge.png)](https://coveralls.io/r/sul-dlss/triannon) [![Dependency Status](https://gemnasium.com/sul-dlss/triannon.svg)](https://gemnasium.com/sul-dlss/triannon) [![Gem Version](https://badge.fury.io/rb/triannon.svg)](http://badge.fury.io/rb/triannon)

# Triannon

Store Open Annotation in Fedora4 to support the Linked Data for Libraries use cases.

## Installation into Your Rails Application

Add this line to your Rails application's Gemfile

```ruby
gem 'triannon'
```

Then execute:
```console
$ bundle install
```

Then run the triannon generator:
```console
$ rails g triannon:install
```

Edit the `config/triannon.yml` file:

* `ldp_url:` Points to the root annotations container on your LDP server
* `solr_url:` Points to the baseurl of Solr instance configured for Triannon
* `triannon_base_url:` Used as the base url for all annotations hosted by your Triannon server.  Identifiers from the LDP server will be appended to this base-url.  Generally something like "https://your-triannon-rails-box/annotations", as "/annotations" is added to the path by the Triannon gem

Generate the root annotations container on your LDP server:

```console
$ rake triannon:create_root_container
```

Set up caching for jsonld context documents:

* by using Rack::Cache for RestClient:

  * add to Gemfile:

```ruby
gem 'rest-client'
gem 'rack-cache'
gem 'rest-client-components'
```

    * bundle install

  * create a  config/initializers/rest_client.rb

```ruby
require 'restclient/components'
require 'rack/cache'
RestClient.enable Rack::Cache,
  metastore: "file:#{Rails.root}/tmp/rack-cache/meta",
  entitystore: "file:#{Rails.root}/tmp/rack-cache/body",
  default_ttl:  86400, # when to recheck, in seconds (daily = 60 x 60 x 24)
  verbose: false
```


## Client Interactions with Triannon

### Get a list of annos
as a IIIF Annotation List (see http://iiif.io/api/presentation/2.0/#other-content-resources)

* `GET`: `http://(host)/annotations/search?targetUri=some.url.org`

Search Parameters:
* `targetUri` - matches URI for target, with or without http or https scheme prefix
* `bodyUri` - matches URI for target, with or without http or https scheme prefix
* `bodyExact` - matches body characters exactly
* `bodyKeyword` - matches terms in body characters
* `motivatedBy` - matches fragment part of motivation predicate URI, e.g.  commenting, tagging, painting

* use HTTP `Accept` header with mime type to indicate desired format
  * default:  jsonld
    * `Accept`: `application/ld+json`
  * also supports turtle, rdfxml, json, html
    * `Accept`: `application/x-turtle`

### Get a particular anno
`GET`: `http://(host)/annotations/(anno_id)`

* use HTTP `Accept` header with mime type to indicate desired format
  * default:  jsonld
    * indicate desired context url in the HTTP Accept header thus:
      * `Accept`: `application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"`
	  * `Accept`: `application/ld+json; profile="http://iiif.io/api/presentation/2/context.json"`
  * also supports turtle, rdfxml, json, html
    * indicated desired context url for jsonld as json in the HTTP Link header thus:
      * `Accept`: `application/json`
      * `Link`: `http://www.w3.org/ns/oa.json; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"`
        * note that the "type" part is optional and refers to the type of the rel, which is the reference for all json-ld contexts.
  * see https://github.com/sul-dlss/triannon/blob/master/app/controllers/triannon/annotations_controller.rb #show method for mime formats accepted

#### JSON-LD context
You can request IIIF or OA context for jsonld.

The correct way:
* use HTTP `Accept` header with mime type and context url:
  * `Accept`: `application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"`
  * `Accept`: `application/ld+json; profile="http://iiif.io/api/presentation/2/context.json"`

You can also use either of these methods (with the correct HTTP Accept header):

* `GET`: `http://(host)/annotations/iiif/(anno_id)`
* `GET`: `http://(host)/annotations/(anno_id)?jsonld_context=iiif`

* `GET`:` http://(host)/annotations/oa/(anno_id)`
* `GET`: `http://(host)/annotations/(anno_id)?jsonld_context=oa`

Note that OA (Open Annotation) is the default context if none is specified.

### Create an anno
`POST`: `http://(host)/annotations`
* the body of the HTTP request should contain the annotation, as jsonld, turtle, or rdfxml
  * Wrap the annotation in an object, as such:
  * `{ "commit" => "Create Annotation", "annotation" => { "data" => oa_jsonld } }`
* the `Content-Type` header should be the mime type matching the body
* the anno to be created should NOT already have an assigned @id
* to get a particular format back, use the HTTP `Accept` header
  * to get a particular context for jsonld, do one of the following:
    * `Accept`: `application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"`
    * `Accept`: `application/ld+json; profile="http://iiif.io/api/presentation/2/context.json"`
  * to get a particular jsonld context for jsonld as json, specify it in the HTTP Link header thus:
    * `Accept`: `application/json`
    * `Link`: `http://www.w3.org/ns/oa.json; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"`
      * note that the "type" part is optional and refers to the type of the rel, which is the reference for all json-ld contexts.

### Delete an anno
`DELETE`: `http://(host)/annotations/(anno_id)`


# Running This Code in Development

There is a bundled rake task for running triannon in a test rails application, but there is some one-time set up.

## One time setup

### Set up a local instance of Fedora4
```console
$ rake jetty:download
$ rake jetty:unzip
$ rake jetty:environment
```

### Turn off basic authorization in local Fedora4
```console
rake triannon:disable_fedora_auth_in_jetty
```

### Set up a local Triannon flavored Solr
```console
rake triannon:solr_jetty_setup
```

### Set up the testing Rails app that uses triannon gem
```console
$ rake engine_cart:generate # (first run only)
```

### Start jetty
```console
$ rake jetty:start
```

Note that jetty can be very sloooooooow to start up with Fedora and Solr.

#### Check if Solr is up
Go to http://localhost:8983/solr/#/triannon
or to http://localhost:8983/solr/triannon/select

If all is well, you will not get an error message; the triannon core exists in Solr.  If all is not
well, try:

```console
$ rake jetty:stop
$ rake triannon:solr_jetty_setup
$ rake triannon:disable_fedora_auth_in_jetty
$ rake jetty:start
```

and then check again.


#### Check if Fedora4 is up
Go to http://localhost:8983/fedora/rest/

If all is well, you will not get an error message.  If all is not well, try:

```console
$ rake jetty:stop
$ rake jetty:clean
$ rake triannon:solr_jetty_startup
$ rake triannon:disable_fedora_auth_in_jetty
$ rake jetty:start
```

and check for Solr and Fedora again.

#### Generate root annotations container
After you ensure that Fedora4 is running:

```console
$ cd spec/internal
$ rake triannon:create_root_container
$ cd ../..
```

#### Configure spec/internal/config/triannon.yml as specified above
You probably won't need to change this file.
```console
$ vi spec/internal/config/triannon.yml
```


## Run the testing Rails application
```console
$ rake jetty:start  # if it isn't still running
$ rake triannon:server
$ <cntl + C> # to stop Rails application
$ rake jetty:stop # to stop Fedora and Solr
```

The app will be running at localhost:3000

# Running the Tests

Run tests:

```console
$ rake spec
```

