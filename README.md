# Cerberus annotations

Demonstration linked data application to support the Linked Data for Libraries use cases.

## Tests

Run tests:

```console
$ rake
```

## Installation

Add this line to your gemfile

```ruby
gem 'cerberus-annotations'
```

Then execute:

```console
$ bundle
```

Then run the cerberus generator:

```console
$ rails g cerberus:annotations:install
```

## Running the application in development

There is a bundled rake task for running the test app:

```console
$ rake engine_cart:generate # (first run only)
$ rake cerberus:server
```
