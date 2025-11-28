# fitgem_oauth2

[![Build Status](https://travis-ci.org/gupta-ankit/fitgem_oauth2.svg?branch=master)](https://travis-ci.org/gupta-ankit/fitgem_oauth2)
[![Code Climate](https://codeclimate.com/github/gupta-ankit/fitgem_oauth2/badges/gpa.svg)](https://codeclimate.com/github/gupta-ankit/fitgem_oauth2)
[![Test Coverage](https://api.codeclimate.com/v1/badges/038c7943c9a714eb50f9/test_coverage)](https://codeclimate.com/github/gupta-ankit/fitgem_oauth2/test_coverage)

The fitgem_oauth2 gem allows developers to use the [Fitbit API](http://dev.fitbit.com/docs). Certain parts of the code,
structure, and the API are heavily based on the [fitgem](https://github.com/whazzmaster/fitgem) gem which uses OAuth 1.0 for accessing the Fitbit API.

## Dependencies

### Faraday Requirement
This gem requires **Faraday ~> 2.6** for HTTP operations. Faraday is a popular HTTP client library for Ruby that provides a simple interface for making API requests.

**Note**: If you're upgrading from a previous version of this gem, please ensure your application is compatible with Faraday 2.x. See the [Upgrade Guide](#upgrade-guide) section below for more details.



## Usage
Add the following line to use the fitgem_oauth2 gem

```ruby
gem 'fitgem_oauth2'
```

# Quickstart
If you are using fitgem_oauth2 in a Rails application, we have a sample rails application to test out the gem. It is available here https://github.com/gupta-ankit/FitgemOAuth2Rails

## Upgrade Guide

### Upgrading from Previous Versions

#### Faraday 1.x to 2.x Migration
If you're upgrading from a version that used Faraday 1.x, please note the following changes:

**What changed:**
- Upgraded Faraday dependency from `~> 1.0.1` to `~> 2.6`
- Updated internal Faraday adapter configuration for compatibility
- Maintained full backward compatibility for public API

**Action required:**
- No breaking changes to the gem's public API
- Your existing code should continue to work without modifications
- Ensure your application's Faraday version constraints allow `~> 2.6`

**Compatibility:**
- All HTTP methods (GET, POST, PUT, DELETE) maintain the same interface
- OAuth2 authentication flow unchanged
- Response parsing and error handling remain consistent

#### Manual Installation
If you encounter dependency conflicts, you may need to manually update Faraday:

```bash
bundle update faraday
```

Or in your Gemfile:
```ruby
gem 'faraday', '~> 2.6'
gem 'fitgem_oauth2'
```

### Getting Help
If you encounter issues during the upgrade:
1. Check that your application meets the Faraday ~> 2.6 requirement
2. Review the [Fitbit API documentation](http://dev.fitbit.com/docs)
3. Open an issue on the [GitHub repository](https://github.com/gupta-ankit/fitgem_oauth2)

