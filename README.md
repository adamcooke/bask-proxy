# Bask for Procodile

Bask is an HTTP proxy server that allows you to automatically start & route requests to applications that use [Procodile](https://github.com/adamcooke/procodile).

## Feautres

* Automatically start the application when a request is received for it.
* Automatically stop the application when no requests have been received for a while.
* Route HTTP requests to the appropriate backends based on the hostname.

## CLI Reference

* `bask start` - starts the bask proxy & DNS server
* `bask stop` - stops the proxy & DNS server
* `bask status` - says whether or not bask is running and other bask details
* `bask apps` - lists the status of all apps configured by bask
