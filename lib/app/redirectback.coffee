#
# Redirects back based on query params, session, or w/e else.
# Code stolen from Force, thanks @dzucconi!
#

_ = require 'underscore'
{ parse } = require 'url'

redirectFallback = '/'
whitelistHosts = [
  'internal'
  'localhost'
  'artsy.net'
]
whitelistProtocols = [
  'http:'
  'https:'
  null
]

hasStatus = (args) ->
  args.length is 2 and typeof args[0] is 'number'

bareHost = (hostname) ->
  return 'internal' unless hostname?
  _.last(hostname.split('.'), subdomainOffset = 2).join '.'

normalizeAddress = (address) ->
  address.replace /^http(s?):\/+/, 'http://'

safeAddress = (address) ->
  parsed = parse(normalizeAddress(address), false, true)
  _.contains(whitelistProtocols, parsed.protocol) and
  _.contains(whitelistHosts, bareHost(parsed.hostname))

sanitizeRedirect = (address) ->
  if safeAddress(address) then address else redirectFallback

module.exports = (req, res) ->
  url = req.body['redirect-to'] or
        req.query['redirect-to'] or
        req.params.redirect_uri or
        req.session.redirectTo or
        '/'
  res.redirect sanitizeRedirect(url)
