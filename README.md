[![Build Status](https://travis-ci.org/sul-dlss/triannon.svg?branch=master)](https://travis-ci.org/sul-dlss/triannon) [![Dependency Status](https://gemnasium.com/sul-dlss/triannon.svg)](https://gemnasium.com/sul-dlss/triannon) [![Gem Version](https://badge.fury.io/rb/triannon.svg)](http://badge.fury.io/rb/triannon)

# Triannon

Demonstration Open Annotation to support the Linked Data for Libraries use cases.

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

## Running the application in development

There is a bundled rake task for running the test app:

```console
$ rake engine_cart:generate # (first run only)
$ rake triannon:server
```
