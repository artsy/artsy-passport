#
# Redirects back based on query params, session, or w/e else.
# Code stolen from Force, thanks @dzucconi!
#
opts = require '../options'
sanitizeRedirect = require './sanitize_redirect'

module.exports = (req, res) ->
  url = sanitizeRedirect(
    (opts.afterSignupPagePath if req.artsyPassportSignedUp and !req.session.skipOnboarding) or
    req.body['redirect-to'] or
    req.query['redirect-to'] or
    req.params.redirect_uri or
    req.session.redirectTo or
    '/'
  )
  res?.redirect url
  return url
