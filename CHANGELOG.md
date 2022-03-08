 # CHANGELOG

## v0.9.2 - 2022-03-08

### Changed
* Doesn't crash when "query" is not a string

 ## v0.9.1 - 2022-01-21

### Changed
   * Client ip is now properly serialize as a string

 ## v0.9 - 2022-01-05

### Added
* adds more fields to the log:
  * referer
  * user_agent
  * x_forwarded_for
  * x_forwarded_proto
  * x_forwarded_port
  * via


## v0.8 - 2021-11-22

### Added
`operationName` for GQL requests

### Changed
`path` now always path and not sometimes `operationName`


## v0.7 - 2021-08-16

### Added

* configurable sampling of successful requests. Use the :success_log_sampling_ratio configuration in init and specify a ratio of the sample to log. Ratio can support a precision up to 4 digits
* update dependencies
## v0.6 - 2021-04-08

### Added

* ignore request path options to `Uinta.Plug`, to filter out request unwanted unless HTTP status returned
is not a 200-level status
* Adds a CHANGELOG
* Adds a duration_ms as a number

### Changed

* Upgraded the package dependencies


## v0.5 - 2020-11-04

### Added
* ignore request path options to `Uinta.Plug`, to filter out request unwanted unless HTTP status returned
is not a 200-level status


## v0.4.2 - 2020-03-31

### Changed

* properly handle GraphQL queries with no commas


## v0.4.1 - 2020-03-31

### Changed

* handle array arguments properly in the regex


## v0.4.0 - 2020-03-30

### Changed

* better handle queries with no operationName
