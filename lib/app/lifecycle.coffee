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
Mailcheck = require 'mailcheck'
crypto = require 'crypto'

@onLocalLogin = (req, res, next) ->
  passport.authenticate('local') req, res, (err) ->
    if req.xhr
      if err
        res.send 500, { success: false, error: err.message }
      else if not req.user?
        res.send 403, { success: false, error: "Invalid email or password." }
      else if req.user?
        res.send { success: true, user: req.user.toJSON() }
    else
      if err?.response?.body?.error_description is 'invalid email or password'
        res.redirect opts.loginPagePath + '?error=Invalid email or password.'
      else if err
        next err
      else if req.artsyPassportSignedUp
        res.redirect opts.afterSignupPagePath
      else
        redirectBack req, res

@onLocalSignup = (req, res, next) ->
  req.artsyPassportSignedUp = true
  request
    .post(opts.ARTSY_URL + '/api/v1/user')
    .set('X-Xapp-Token': artsyXapp.token)
    .send(
      name: req.body.name
      email: req.body.email
      password: req.body.password
    ).end (err, sres) ->
      if err and err.message is 'Email is invalid.'
        suggestion = Mailcheck.run(email: req.body.email)?.full
        msg = "Email is invalid."
        msg += " Did you mean #{suggestion}?" if suggestion
        if req.xhr
          res.send 403, { success: false, error: msg }
        else
          res.redirect opts.signupPagePath + "?error=#{msg}"
      else if err and req.xhr
        res.send 500, { success: false, error: err.message }
      else if err
        next new Error err
      else
        next()

@beforeSocialAuth = (provider) -> (req, res, next) ->
  options = {}
  options.scope = switch provider
    when 'linkedin' then ['r_basicprofile', 'r_emailaddress']
    else 'email'
  # Twitter OAuth 1 doesn't support `state` param csrf out of the box.
  # So we implement it ourselves ( -__- )
  # https://twittercommunity.com/t/is-the-state-parameter-supported/1889
  if provider is 'twitter' and not req.query.state
    rand = Math.random().toString()
    h = crypto.createHash('sha1').update(rand).digest('hex')
    req.session.twitterState = h
    options.callbackURL = "#{opts.APP_URL}#{opts.twitterCallbackPath}?state=#{h}"
  passport.authenticate(provider, options)(req, res, next)

@afterSocialAuth = (provider) -> (req, res, next) ->
  return next(new Error "#{provider} denied") if req.query.denied
  # Twitter OAuth 1 doesn't support `state` param csrf out of the box.
  # So we implement it ourselves ( -__- )
  # https://twittercommunity.com/t/is-the-state-parameter-supported/1889
  if provider is 'twitter' and req.query.state isnt req.session.twitterState
    err = new Error "Must pass a valid `state` param."
    return next err
  # Determine if we're linking the account and handle any Gravity errors
  # that we can do a better job explaining and redirecting for.
  providerName = switch provider
    when 'linkedin' then 'LinkedIn'
    else _s.capitalize provider
  linkingAccount = req.user?
  passport.authenticate(provider) req, res, (err) ->
    if err?.response?.body?.error is 'User Already Exists'
      if req.socialProfileEmail
        msg = "A user with the email address #{req.socialProfileEmail} already " +
              "exists. Log in to Artsy via email and password and link " +
              "#{providerName} in your settings instead."
      else
        msg = "#{providerName} account previously linked to Artsy. " +
              "Log in to your Artsy account via email and password and link" +
              "#{providerName} in your settings instead."
      res.redirect opts.loginPagePath + '?error=' + msg
    else if err?.response?.body?.error is 'Another Account Already Linked'
      msg = "#{providerName} account already linked to another Artsy account. " +
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

@onError = (err, req, res, next) ->
  if err.message is 'twitter denied'
    res.redirect opts.loginPagePath + "?error=Canceled Twitter login"
  else
    next err
