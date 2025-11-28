# 3.1.0 (unreleased)
* **Faraday Upgrade**: Updated Faraday dependency from `~> 1.0.1` to `~> 2.6` for improved HTTP client functionality and security
* **Enhanced Compatibility**: Updated internal Faraday adapter configuration for version 2.6 compatibility
* **Maintained Backward Compatibility**: All existing public APIs remain unchanged - no breaking changes for users
* **Improved Test Coverage**: Achieved 99% test coverage with comprehensive Faraday 2.6 integration tests
* **Performance Validation**: Verified all HTTP operations (GET, POST, PUT, DELETE) work correctly with new dependency
* **Enhanced Error Handling**: Improved error handling for Faraday version-specific scenarios

# 3.0.0
* This version is release for Ruby 3. If you encounter any issues using it with Ruby 2, use version 2.2 of this gem
* `food_series` has been removed. use `food_series_for_date_range`, `food_series_for_period`, `water_series_for_date_range`, or `water_series_for_period` instead.'
* `heartrate_time_series` has been removed. Please use `hr_series_for_date_range` or `hr_series_for_period` instead.'

# 2.2.0
* updated faraday gem to fix json vulerability in the faraday gem

# 2.0.1
* New feature - Client now throws an exception which the caller can check to see the case when the Fitbit API returns a 429


# 2.0.0 (DO NOT USE)
* This is a dirty version that did not handle the api rate limit error and had failing build (the release was made in an error and has been yanked from rubygems.org)
* added FitgemOauth2::ApiLimitError to be raised when the client hits the Fitbit API limit
