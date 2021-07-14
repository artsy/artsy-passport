//
// Cleans out urls so they are safe to redirect to inside of an artsy.net app.
// Code stolen from Force, thanks @dzucconi!
//
const _ = require('underscore')
const parse = require('url').parse

const redirectFallback = '/'
const whitelistHosts = ['internal', 'localhost', 'artsy.net']
const whitelistProtocols = ['http:', 'https:', null]

const bareHost = function(hostname) {
  if (hostname == null) return 'internal'
  return _.last(hostname.split('.'), 2).join('.')
}

const normalizeAddress = function(address) {
  return address.replace(/^http(s?):\/+/, 'http://').replace(/\s/g, '')
}

const safeAddress = function(address) {
  var parsed = parse(normalizeAddress(address), false, true)
  return (
    _.contains(whitelistProtocols, parsed.protocol) &&
    _.contains(whitelistHosts, bareHost(parsed.hostname))
  )
}

module.exports = function(address) {
  return safeAddress(address) ? address : redirectFallback
}
