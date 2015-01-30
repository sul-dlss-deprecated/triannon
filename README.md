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
$ cp config/solr/solr.xml jetty/solr
$ cp config/solr/triannon-core jetty/solr
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
