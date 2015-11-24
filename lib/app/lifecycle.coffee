#
# Middleware functions that help control what happens before and after
# logging in or signing up.
#

_ = require 'underscore'
opts = require '../options'
passport = require 'passport'
qs = require 'querystring'

@onLocalLogin = (req, res, next) ->
  passport.authenticate('local') req, res, (err) ->
    if req.xhr and err
      res.send 403, { success: false, error: err }
    else if req.xhr and req.user?
      res.send { success: true, user: req.user.toJSON() }
    else if req.xhr and not req.user?
      res.send 500, { success: false, error: "Missing user." }
    else
      next err

@beforeSocialAuth = (provider) -> (req, res, next) ->
  passport.authenticate(provider,
    if provider is 'linkedin'
      scope: ['r_basicprofile', 'r_emailaddress']
    else
      scope: 'email'
  )(req, res, next)

@afterSocialAuth = (provider) -> (req, res, next) ->
  return next(new Error "#{provider} denied") if req.query.denied
  linkingAccount = req.user?
  passport.authenticate(provider,
    if provider is 'linkedin'
      scope: ['r_basicprofile', 'r_emailaddress']
    else
      scope: 'email'
  ) req, res, (err) ->
    if err?.response?.body?.error is 'User Already Exists'
      msg = "Facebook account previously linked to Artsy. " +
            "Log in to your Artsy account and re-link " +
            "Facebook in your settings instead."
      res.redirect opts.loginPagePath + '?error=' + msg
    else if err?.response?.body?.error is 'Another Account Already Linked'
      msg = "Twitter account linked to another Artsy account. " +
            "Try logging out and back in with Twitter. Then consider " +
            "deleting that user account and re-linking Twitter. "
      res.redirect opts.settingsPagePath + '?error=' + msg
    else if err?
      next err
    else if linkingAccount
      res.redirect opts.settingsPagePath
    else
      next()

# We have to hack around passport by capturing a custom error message that
# indicates we've created a user in one of passport's social callbacks. If we
# catch that error then we'll attempt to redirect back to login and strip out
# the expired Facebook/Twitter credentials.
@socialSignup = (provider) -> (err, req, res, next) ->
  unless err.message is 'artsy-passport: created user from social'
    return next(err)
  # Redirect to a social login url stripping out the Facebook/Twitter
  # credentials (code, oauth_token, etc). This will be seemless for Facebook,
  # but since Twitter has a ask for permision UI it will mean asking
  # permission twice. It's not apparent yet why we can't re-use the
  # credentials... without stripping them we get errors from FB & Twitter from
  # the Gravity API.
  querystring = qs.stringify(
    _.omit(req.query, 'code', 'oauth_token', 'oauth_verifier')
  )
  url = (if provider is 'twitter' then \
    opts.twitterLastStepPath else opts.facebookPath) + '?' + querystring
  res.redirect url

# Might be able to move this into `onAccessToken` in callbacks
@signup = (req, res, next) ->
  request.post(opts.ARTSY_URL + '/api/v1/user').send(
    name: req.body.name
    email: req.body.email
    password: req.body.password
    xapp_token: opts.XAPP_TOKEN
  ).end onCreateUser(next)

onCreateUser = (next) -> (err, res) ->
  if res.status isnt 201
    errMsg = res.body.message
  else
    errMsg = err?.text
  if errMsg then next(errMsg) else next()
