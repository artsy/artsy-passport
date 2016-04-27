//
// Cleans out urls so they are safe to redirect to inside of an artsy.net app.
// Code stolen from Force, thanks @dzucconi!
//
var _ = require('underscore')
var parse = require('url').parse

var redirectFallback = '/'
var whitelistHosts = ['internal', 'localhost', 'artsy.net']
var whitelistProtocols = ['http:', 'https:', null]

var hasStatus = function(args) {
  return args.length === 2 && typeof args[0] === 'number'
}

var bareHost = function(hostname) {
  if (hostname == null) return 'internal'
  return _.last(hostname.split('.'), 2).join('.')
}

var normalizeAddress = function(address) {
  return address.replace(/^http(s?):\/+/, 'http://').replace(/\s/g, '')
}

var safeAddress = function(address) {
  var parsed = parse(normalizeAddress(address), false, true)
  return (
    _.contains(whitelistProtocols, parsed.protocol) &&
    _.contains(whitelistHosts, bareHost(parsed.hostname))
  )
}

module.exports = function(address) {
  return safeAddress(address) ? address : redirectFallback
}
