#
# Middleware functions that help control what happens before and after
# logging in or signing up.
#

_ = require 'underscore'
_s = require 'underscore.string'
opts = require '../options'
passport = require 'passport'
qs = require 'querystring'
redirectBack = require './redirectback'
request = require 'superagent'
artsyXapp = require 'artsy-xapp'

@onLocalLogin = (req, res, next) ->
  passport.authenticate('local') req, res, (err) ->
    if req.xhr and err
      res.send 403, { success: false, error: err }
    else if req.xhr and req.user?
      res.send { success: true, user: req.user.toJSON() }
    else if req.xhr and not req.user?
      res.send 500, { success: false, error: "Missing user." }
    else if err
      next err
    else
      redirectBack req, res

@onLocalSignup = (req, res, next) ->
  request
    .post(opts.ARTSY_URL + '/api/v1/user')
    .set('X-Xapp-Token': artsyXapp.token)
    .send(
      name: req.body.name
      email: req.body.email
      password: req.body.password
    ).end (err, res) ->
    errMsg = if res.status isnt 201 then res.body.message else err?.text
    if errMsg then next(new Error errMsg) else next()

@beforeSocialAuth = (provider) -> (req, res, next) ->
  passport.authenticate(provider,
    if provider is 'linkedin'
      scope: ['r_basicprofile', 'r_emailaddress']
    else
      scope: 'email'
  )(req, res, next)

@afterSocialAuth = (provider) -> (req, res, next) ->
  return next(new Error "#{provider} denied") if req.query.denied
  providerName = _s.capitalize provider
  linkingAccount = req.user?
  passport.authenticate(provider,
    if provider is 'linkedin'
      scope: ['r_basicprofile', 'r_emailaddress']
    else
      scope: 'email'
  ) req, res, (err) ->
    if err?.response?.body?.error is 'User Already Exists'
      msg = "#{providerName} account previously linked to Artsy. " +
            "Log in to your Artsy account and re-link " +
            "#{providerName} in your settings instead."
      res.redirect opts.loginPagePath + '?error=' + msg
    else if err?.response?.body?.error is 'Another Account Already Linked'
      msg = "#{providerName} account linked to another Artsy account. " +
            "Try logging out and back in with #{providerName}. Then consider " +
            "deleting that user account and re-linking #{providerName}. "
      res.redirect opts.settingsPagePath + '?error=' + msg
    else if err?
      next err
    else if linkingAccount
      res.redirect opts.settingsPagePath
    else if req.artsyPassportSignedUp and provider is 'twitter'
      res.redirect opts.twitterLastStepPath
    else if req.artsyPassportSignedUp
      res.redirect opts.afterSignupPagePath
    else
      redirectBack req, res

@ensureLoggedInOnAfterSignupPage = (req, res, next) ->
  res.redirect opts.loginPagePath unless req.user?
  next()
