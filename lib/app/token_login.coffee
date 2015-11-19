#
# Middleware to allow log in by passing x-access-token in the headers or
# trust_token in the query params.
#

opts = require '../options'
qs = require 'querystring'

@headerLogin = (req, res, next) ->
  return next() if req.path is opts.logoutPath
  if token = req.get('X-Access-Token') or req.query.access_token
    req.login new opts.CurrentUser(accessToken: token), next
  else
    next()

@trustTokenLogin = (req, res, next) ->
  return next() unless (token = req.query.trust_token)?
  settings =
    grant_type: 'trust_token'
    client_id: opts.ARTSY_ID
    client_secret: opts.ARTSY_SECRET
    code: token
  request
    .post "#{opts.ARTSY_URL}/oauth2/access_token"
    .send settings
    .end (err, response) ->
      return next() if err? or not response.ok
      user = new opts.CurrentUser accessToken: response.body.access_token
      req.login user, (err) ->
        return next() if err?
        path = req.url.split('?')[0]
        params = _.omit req.query, 'trust_token'
        path += "?#{qs.stringify params}" unless _.isEmpty params
        res.redirect path
