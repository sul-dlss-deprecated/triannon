[![Build Status](https://travis-ci.org/sul-dlss/triannon.svg?branch=master)](https://travis-ci.org/sul-dlss/triannon) [![Dependency Status](https://gemnasium.com/sul-dlss/triannon.svg)](https://gemnasium.com/sul-dlss/triannon) [![Gem Version](https://badge.fury.io/rb/triannon.svg)](http://badge.fury.io/rb/triannon)

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

* `ldp_url:` Points to the root annotations container in your LDP server
* `triannon_base_url:` Used as the base url for all annotations hosted by your Triannon server.  Identifiers from the LDP server will be appended to this base-url.

## Running the application in development

There is a bundled rake task for running the test app:

```console
# One time setup: run the following 3 commands
$ rake jetty:download
$ rake jetty:unzip
$ rake engine_cart:generate # (first run only)

# Run the test app
$ rake triannon:server
```
