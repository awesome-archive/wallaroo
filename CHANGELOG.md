# Change Log

All notable changes to Wallaroo will be documented in this file.

## [unreleased] - unreleased

### Fixed


### Added


### Changed


## [0.6.1] - 2018-12-31

### Added

- Add support for windowing ([PR #2735](https://github.com/WallarooLabs/wallaroo/pull/2735))

## [0.6.0] - 2018-11-30

### Fixed

- Gradually back off when attempting to reconnect on data channel
- There is no longer a problem when using more workers than there are partitions
- No longer treat state computation stages as a special case. This results in fewer allocations and better performance

### Added

- Python 3 Support for Connectors
- Add parallel stateless steps to joining workers

### Changed

- Streamlined Wallaroo Python API
- Connectors API Update
- Simplify the Python API for adding a computation to a pipeline

## [0.5.4] - 2018-10-31

### Added

- Added Python 3 support for Wallaroo in our Docker image and in installations via Vagrant, Wallaroo Up (on Ubuntu (Xenial, Artful, and Bionic) and Debian (Stretch and Buster)), as well as for installation from source on systems with Python 3.5 or higher (python3-dev is also required).

### Changed

- Deprecate giles receiver in favor of data receiver ([PR #2341](https://github.com/WallarooLabs/wallaroo/pull/2341))

## [0.5.3] - 2018-09-28

### Fixed

- Python's argparse and other libraries which require properly intialized python arguments should no longer fail in certain cases in machida

### Added

- Added support for Fedora 26/27, Amazon Linux 2, Oracle Linux, Ubuntu Artful, and Debian Jessie/Buster Linux distributions via Wallaroo Up
- Checkpointing protocol for regular checkpointing of application state
- Support for rollback to most recent checkpoint on recovery
- Support for replicated recovery data
- Added preview release of the Python Connectors API
- Added connector scripts for Kafka, Kinesis, RabbitMQ, Redis, S3, and UDP
- Added a template for a Postgres connector script

## [0.5.2] - 2018-08-24

### Added

- Added Wallaroo Up to automate development environment setup on multiple Linux distributions
- Added support for Fedora 28, CentOS 7, and Debian Stretch Linux distributions via Wallaroo Up
- Added Vagrant as an option for trying out the Wallaroo Go
- Added Docker as an option for trying out the Wallaroo Go

## [0.5.1] - 2018-08-01

### Fixed

- Ensure that parallel stateless computations always run independently ([PR #2322](https://github.com/wallaroolabs/wallaroo/pull/2322))

### Changed

- Filter none/nil in Decoder for Python/Go API's ([PR #2259](https://github.com/wallaroolabs/wallaroo/pull/2259))

## [0.5.0] - 2018-07-25

### Fixed

- Filter `None` values in machida compute_multi results ([PR #2179](https://github.com/wallaroolabs/wallaroo/pull/2179))
- Fix busy-loop/scheduler yield bugs in TCPConnection-related classes ([PR #2142](https://github.com/wallaroolabs/wallaroo/pull/2142))
- Fix errors in Python decorator API documentation ([PR #2124](https://github.com/wallaroolabs/wallaroo/pull/2124))
- Improve autoscale performance and reliability, and fix related edge case bugs ([PR #2122](https://github.com/wallaroolabs/wallaroo/pull/2122))
- Fix bug that caused Wallaroo to shut down when connecting a new source after a 3->2 shrink ([PR #2072](https://github.com/wallaroolabs/wallaroo/pull/2072))
- Correctly remove boundary references when worker leaves ([PR #2073](https://github.com/wallaroolabs/wallaroo/pull/2073))
- Correctly update routers after shrink ([PR #2018](https://github.com/wallaroolabs/wallaroo/pull/2018))
- Only try to shrink if supplied worker names are still in the cluster ([PR #2034](https://github.com/wallaroolabs/wallaroo/pull/2034))
- Fix bug when using cluster_shrinker with non-initializer ([PR #2011](https://github.com/wallaroolabs/wallaroo/pull/2011))
- Ensure that all running workers migrate to joiners ([PR #2027](https://github.com/wallaroolabs/wallaroo/pull/2027))
- Clean up recovery files during shrink ([PR #2012](https://github.com/wallaroolabs/wallaroo/pull/2012))
- Ensure that new sources don't try to connect to old workers ([PR #2004](https://github.com/wallaroolabs/wallaroo/pull/2004))
- Fail when control channel can't listen ([PR #1982](https://github.com/wallaroolabs/wallaroo/pull/1982))
- Only create output file for Giles sender when writing ([PR #1964](https://github.com/wallaroolabs/wallaroo/pull/1964))

### Added

- Add support for dynamic keys ([PR #2265](https://github.com/WallarooLabs/wallaroo/pull/2265))
- Inform joining worker to shut down on join error ([PR #2086](https://github.com/wallaroolabs/wallaroo/pull/2086))
- Add partition count observability query ([PR #2081](https://github.com/wallaroolabs/wallaroo/pull/2081))
- Add support for multiple sinks per pipeline ([PR #2060](https://github.com/wallaroolabs/wallaroo/pull/2060))
-  Allow joined worker to recover with original command line ([PR #1933](https://github.com/wallaroolabs/wallaroo/pull/1933))
- Add support for query requesting information about partition step distribution across workers ([PR #2025](https://github.com/wallaroolabs/wallaroo/pull/2025))
- Add tool to allow an operator to shrink a Wallaroo cluster ([PR #2005](https://github.com/wallaroolabs/wallaroo/pull/2005))

### Changed

- Clean up external message protocol ([PR #2032](https://github.com/wallaroolabs/wallaroo/pull/2032))
- Remove "name()" from StateBuilder interface ([PR #1988](https://github.com/wallaroolabs/wallaroo/pull/1988))

## [0.4.3] - 2018-05-18

### Added

- Add Machida with Resilience to Wallaroo in Docker

## [0.4.2] - 2018-05-14

### Fixed

- Improve Python exception handling in user provided functions ([PR #2194](https://github.com/WallarooLabs/wallaroo/pull/2194))

### Added

- Add Artful Aardvark Support ([PR #2189](https://github.com/WallarooLabs/wallaroo/pull/2189))
- Add Wallaroo in Vagrant ([PR #2183](https://github.com/WallarooLabs/wallaroo/pull/2183))
- Add documentation for Wallaroo in Docker on Windows([PR #2177](https://github.com/WallarooLabs/wallaroo/pull/2177))

## [0.4.1] - 2018-03-14

### Fixed

- Go API: Fixed bug in state computation that return multiple results
- Kafka Client: Update to pony-kafka release 0.3.4 for bugfix regarding partial messages

## [0.4.0] - 2018-01-12

### Fixed

- Do not force shrink count to a minimum of 1 ([PR #1931](https://github.com/wallaroolabs/wallaroo/pull/1931))
- Fix bug that caused worker joins to fail after the first successful round. ([PR #1927](https://github.com/wallaroolabs/wallaroo/pull/1927))

### Added

- Add "Running Wallaroo" section to book ([PR #1914](https://github.com/wallaroolabs/wallaroo/pull/1914))

### Changed

- New version of Python API based on decorators ([PR #1833](https://github.com/wallaroolabs/wallaroo/pull/1833))

## [0.3.3] - 2018-01-09

### Fixed

- Fix shrink autoscale query reply ([PR #1862](https://github.com/wallaroolabs/wallaroo/pull/1862))

### Added

- Initial Go API ([PR #1866](https://github.com/wallaroolabs/wallaroo/pull/1866))

### Changed

- Turn off building with AVX512f CPU extensions to work around a LLVM bug ([PR #1932](https://github.com/WallarooLabs/wallaroo/pull/1932))

## [0.3.2] - 2017-12-28

### Fixed

- Updates to documentation

## [0.3.1] - 2017-12-22

### Fixed

- Updates to documentation

## [0.3.0] - 2017-12-18

### Fixed

- Get ctrl-c to shutdown cluster after autoscale ([PR #1760](https://github.com/wallaroolabs/wallaroo/pull/1760))
- Send all unacked messages when resuming normal sending at OutgoingBoundary ([PR #1766](https://github.com/wallaroolabs/wallaroo/pull/1766))
- Fix bug in Python word count partitioning logic ([PR #1723](https://github.com/wallaroolabs/wallaroo/pull/1723))
- Add support for chaining State Partition -> Stateless Partition ([PR #1670](https://github.com/wallaroolabs/wallaroo/pull/1670))
- Fix Sender to properly dispose of files ([PR #1673](https://github.com/wallaroolabs/wallaroo/pull/1673))
- Create ProxyRouters to all required steps during initialization

### Added

- Add join for more than 1 worker simultaneously ([PR #1759](https://github.com/wallaroolabs/wallaroo/pull/1759))
- Add stateless partition shrink recalculation ([PR #1767](https://github.com/wallaroolabs/wallaroo/pull/1767))
- Add full support for partition routing to newly joined worker ([PR #1730](https://github.com/wallaroolabs/wallaroo/pull/1730))
- Shutdown cluster cleanly when SIGTERM or SIGINT is received ([PR #1705](https://github.com/wallaroolabs/wallaroo/pull/1705))

### Changed

- Don't report a cluster as ready to work until node connection protocol has completed ([PR #1771](https://github.com/wallaroolabs/wallaroo/pull/1771))
- Add Env as argument to source/sink builders ([PR #1734](https://github.com/wallaroolabs/wallaroo/pull/1734))

