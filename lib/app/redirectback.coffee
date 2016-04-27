#
# Redirects back based on query params, session, or w/e else.
# Code stolen from Force, thanks @dzucconi!
#
sanitizeRedirect = require './sanitize_redirect'

module.exports = (req, res) ->
  url = req.body['redirect-to'] or
        req.query['redirect-to'] or
        req.params.redirect_uri or
        req.session.redirectTo or
        '/'
  res.redirect sanitizeRedirect(url)
