[![Build Status](https://travis-ci.org/sul-dlss/triannon.svg?branch=master)](https://travis-ci.org/sul-dlss/triannon) [![Coverage Status](https://coveralls.io/repos/sul-dlss/triannon/badge.png)](https://coveralls.io/r/sul-dlss/triannon) [![Dependency Status](https://gemnasium.com/sul-dlss/triannon.svg)](https://gemnasium.com/sul-dlss/triannon) [![Gem Version](https://badge.fury.io/rb/triannon.svg)](http://badge.fury.io/rb/triannon)

# Triannon

Store Open Annotation RDF in Fedora4 to support the Linked Data for Libraries use cases.

## Installation into Your Existing Rails Application

Add this line to your Rails application's Gemfile

```ruby
gem 'triannon'
```

Then install the gems:

```console
$ bundle install
```

Then run the triannon generator:

```console
$ rails g triannon:install
```


## Configuration

Edit the `config/triannon.yml` file:

* `ldp:` Properties of LDP server
  * `url:` the baseurl of LDP server
  * `uber_container:` name of an LDP Basic Container holding all `anno_containers`
  * `anno_containers:`  names of LDP Basic Containers holding annos
* `solr_url:` Points to the baseurl of Solr instance configured for Triannon
* `triannon_base_url:` Used as the base url for all annotations hosted by your Triannon server.  Identifiers from the LDP server will be appended to this base-url.  Generally something like "https://your-triannon-rails-box/annotations", as "/annotations" is added to the path by the Triannon gem

#### Authorization for Containers:
```
anno_containers:
  foo:
  bar:
    auth:
      users: []
      workgroups:
      - org:wg-A
      - org:wg-B
```

Authorization applies only to POST and DELETE requests. In this example, the `foo` container requires no authorization (all operations are allowed).  On the other hand, the `bar` container requires authorization.  There are no authorized `users`, but two `workgroups` are authorized to modify annos in the container ('org:wg-A' and 'org:wg-B').

#### Authorized Clients:
```
authorized_clients:
  clientA: secretA
# expiry values are in seconds
client_token_expiry: 120
access_token_expiry: 3600
```

When authorization is required on a container, there must be at least one authorized client.  The client credentials are used to validate an authorized client that will present requests on behalf of an authorized user or workgroup (see below for details on the authorization workflow).  The client credentials are not specific to any container.

#### Generate the root annotations containers on your LDP server:

```console
$ rake triannon:create_root_containers
```

  This will generate the uber_container and the anno_containers (aka 'root containers') under the uber_container.

  NOTE:  you MUST create the root containers before creating any annotations.  All annotation MUST be created as a child of a root container.

#### Caching jsonld context documents:

* by using Rack::Cache for RestClient:

  * add to Gemfile:

```ruby
gem 'rest-client'
gem 'rack-cache'
gem 'rest-client-components'
```

  * bundle install

  * create config/initializers/rest_client.rb

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

### READ operations

GET requests do not require authorization, even for containers that are configured with authorization for POST and DELETE requests.

#### Get a list of annos
as a IIIF Annotation List (see http://iiif.io/api/presentation/2.0/#other-content-resources)

* `GET`: `http://(host)/annotations/search?targetUri=some.url.org`

Search Parameters:
* `targetUri` - matches URI for target, with or without http or https scheme prefix
* `bodyUri` - matches URI for target, with or without http or https scheme prefix
* `bodyExact` - matches body characters exactly
* `bodyKeyword` - matches terms in body characters
* `motivatedBy` - matches fragment part of motivation predicate URI, e.g.  commenting, tagging, painting
* `anno_root` - matches the root container of the result annos

* use HTTP `Accept` header with mime type to indicate desired format
  * default:  jsonld
    * `Accept`: `application/ld+json`
  * also supports turtle, rdfxml, json, html
    * `Accept`: `application/x-turtle`

#### Get a list of annos in a particular root container
as a IIIF Annotation List (see http://iiif.io/api/presentation/2.0/#other-content-resources)

* `GET`: `http://(host)/annotations/(root container)/search?targetUri=some.url.org`

Search Parameters as above.

* use HTTP `Accept` header with mime type to indicate desired format
  * default:  jsonld
    * `Accept`: `application/ld+json`
  * also supports turtle, rdfxml, json, html
    * `Accept`: `application/x-turtle`

#### Get a particular anno
`GET`: `http://(host)/annotations/(root container)/(anno_id)`

NOTE:  you may need to URL encode the anno_id (e.g. "6f%2F0e%2F79%2F92%2F6f0e7992-83f5-4f31-8bb7-94a23465fdfb" instead of "6f/0e/79/92/6f0e7992-83f5-4f31-8bb7-94a23465fdfb"), particularly from a web browser.

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

You can also use this method (with the correct HTTP Accept header):

* `GET`: `http://(host)/annotations/(root)/(anno_id)?jsonld_context=iiif`
* `GET`: `http://(host)/annotations/(root)/(anno_id)?jsonld_context=oa`

Note that OA (Open Annotation) is the default context if none is specified.

### WRITE operations

When a container is configured with authorization, it applies to POST and DELETE requests.  For these requests, a valid access token is required in the request header, i.e. 'Authorization': 'Bearer {token_here}' (see details below on how to obtain an access token).

#### Create an anno

Note that annos must be created in an existing root container.

`POST`: `http://(host)/annotations/(root container)`
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

#### Delete an anno
`DELETE`: `http://(host)/annotations/(root container)/(anno_id)`

NOTE: URL encode the anno_id (e.g. "6f%2F0e%2F79%2F92%2F6f0e7992-83f5-4f31-8bb7-94a23465fdfb" instead of "6f/0e/79/92/6f0e7992-83f5-4f31-8bb7-94a23465fdfb")

### Authorization

The triannon authorization is modeled on IIIF proposals, see
  - https://github.com/IIIF/auth
  - http://image-auth.iiif.io/api/image/2.1/authentication.html

The authorization workflow accepts json and returns json (not json-ld).  It involves three phases and triannon manages authorization using cookies, which must be retained across requests.

1. Obtain a client authorization code (short-lived token).  
2. Use client authorization code to submit login credentials for authorized user or workgroup.
3. Obtain an access token for submitting or deleting annotations on behalf of the authorized user or workgroup.

### Authorization Examples

Let's assume we have the authorization configuration noted above.

#### Authorization using `curl`
```sh
# 1. POST client credentials to '/auth/client_identity'
#    to get client authorization code (save cookies)
curl -H "Content-Type: application/json" -X POST -c cookies.txt -d '{"clientId":"clientA","clientSecret":"secretA"}' http://localhost:3000/auth/client_identity
{"authorizationCode":"TExteG5LRDBPUW1OK0JicHRhM2VQaGtTWDRTdzdhVThVS3crKy93OTJwU2g3cHBoZE9kTnB4RDl0OUdzSzZydS0tOGhBdWZhVGJScDVTM0hUMmg0c08xUT09--f9250f535bfb4cdf4b32568aae74b367a781407f"}

# 2. POST login credentials to '/auth/login' (save modified cookies)
curl -H "Content-Type: application/json" -X POST -c cookies.txt -b cookies.txt -d '{"userId":"userA","workgroups":"org:wg-A"}' http://localhost:3000/auth/login?code=TExteG5LRDBPUW1OK0JicHRhM2VQaGtTWDRTdzdhVThVS3crKy93OTJwU2g3cHBoZE9kTnB4RDl0OUdzSzZydS0tOGhBdWZhVGJScDVTM0hUMmg0c08xUT09--f9250f535bfb4cdf4b32568aae74b367a781407f

# 3. GET '/auth/access_token' (save cookies)
curl -H "Content-Type: application/json" -c cookies.txt -b cookies.txt http://localhost:3000/auth/access_token?code=TExteG5LRDBPUW1OK0JicHRhM2VQaGtTWDRTdzdhVThVS3crKy93OTJwU2g3cHBoZE9kTnB4RDl0OUdzSzZydS0tOGhBdWZhVGJScDVTM0hUMmg0c08xUT09--f9250f535bfb4cdf4b32568aae74b367a781407f
{"accessToken":"d09pSG5jVkhFMlVLendBNTdLd1lFZzBjZk5TZE1ONktNcDFiQzhibUV4eklsNURiRFNTbGg5YVFReElLR21HMVhmRzdYSU4vZUxjKzA5OGRjYjFMejJHTmo1UHF1cU00T0ZaNTNWMWVuR2M9LS1FT2RNUkJRbHlaTXU2ZTNvVnAwbGZRPT0=--c0a26b65e91137c82a5a42bcb9fd32f29bdfd0f3","tokenType":"Bearer","expiresIn":1438821498}
```

#### Authorization using ruby `rest-client`
```ruby
require 'rest-client'
triannon_auth = RestClient::Resource.new(
  'http://localhost:3000/auth',
  cookies: {},
  headers: { accept: :json, content_type: :json }
)
# 1. Obtain a client authorization code (short-lived token)
client = { clientId: 'clientA', clientSecret: 'secretA' }
response = triannon_auth["/client_identity"].post client.to_json
triannon_auth.options[:cookies] = response.cookies  # save the cookie data
auth = JSON.parse(response.body)
client_code = auth['authorizationCode']
client_param = "?code=#{client_code}"

# 2. The client POSTs user credentials
user = { userId: 'userA', workgroups: 'org:wg-A' }
response = triannon_auth["/login#{client_param}"].post user.to_json
triannon_auth.options[:cookies] = response.cookies  # save the cookie data

# 3. The client, on behalf of user, obtains a long-lived access token.
response = triannon_auth["/access_token#{client_param}"].get # no content type
triannon_auth.options[:cookies] = response.cookies  # save the cookie data
access = JSON.parse(response.body)
access_token = "Bearer #{access['accessToken']}"
triannon_auth.headers[:Authorization] = access_token
```

See also the `authenticate` method in:
  - https://github.com/sul-dlss/triannon-client/blob/master/lib/triannon-client/triannon_client.rb

# Running This Code in Development

There is a bundled rake task for running triannon in a test rails application, but there is some one-time set up.

## One time setup

### Set up the testing Rails app that uses triannon gem

```console
$ rake engine_cart:generate # (first run only)
```

### Set up a local instance of Fedora4 and Solr

```console
$ rake jetty:download
$ rake jetty:unzip
$ rake jetty:environment
$ rake triannon:jetty_config
```

triannon:jetty_config task does the following:
* turns off basic authorization in Fedora4
* sets up a Triannon flavored Solr core

### Start jetty

```console
$ rake jetty:start
```

Note that jetty can be very sloooooooow (a couple of minutes) to start up with Fedora and Solr.

#### Check if Solr and Fedora are up
Go to 
* http://localhost:8983/solr/#/triannon - Solr admin GUI page, you should not see any error text in your browser 
* http://localhost:8983/solr/triannon/select - actual Solr query; should give http status other than 200 if there is a problem

Go to 
* http://localhost:8983/fedora/rest/ - you should see a fedora object.

If all is not well for Fedora or Solr, try:

```console
$ rake triannon:jetty_reset
```

This stops jetty, cleans out the jetty directory, recreates it anew from the download, configures jetty for Triannon, and starts jetty.  It may take a long time (a couple of minutes) for jetty to restart.

Then check the Solr and Fedora urls again.


#### Generate root annotations containers in Fedora
After you ensure that Fedora is running, you need to create the root anno containers using the configuration of test rails app created by engine_cart:

```console
$ cd spec/internal
$ rake triannon:create_root_containers
$ cd ../..
```

#### Configure spec/internal/config/triannon.yml as specified above
NOTE:  You probably won't need to change this file - it will work with the jetty setup provided.

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

The app will be running at localhost:3000, with root containers "foo" and "blah" available (and empty).

# Running the Tests

Run tests:

```console
$ rake spec
```

