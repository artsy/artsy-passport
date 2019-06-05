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
{ parse, resolve } = require 'url'

@onLocalLogin = (req, res, next) ->
  return next() if req.user and not req.xhr
  passport.authenticate('local') req, res, (err) ->
    if req.xhr
      if err
        res.send 500, { success: false, error: err.message }
      else
        next()
    else
      if err?.response?.body?.error_description is 'invalid email or password'
        res.redirect opts.loginPagePath + '?error=Invalid email or password.'
      else if err
        next err
      else
        next()

@onLocalSignup = (req, res, next) ->
  req.artsyPassportSignedUp = true
  request
    .post(opts.ARTSY_URL + '/api/v1/user')
    .set({
      'X-Xapp-Token': artsyXapp.token,
      'User-Agent': req.get('user-agent'),
      'Referer': req.get('referer')
    })
    .send({
      name: req.body.name
      email: req.body.email
      password: req.body.password
      sign_up_intent: req.body.signupIntent
      sign_up_referer: req.body.signupReferer
      accepted_terms_of_service: req.body.accepted_terms_of_service,
      agreed_to_receive_emails: req.body.agreed_to_receive_emails,
      recaptcha_token: req.body.recaptcha_token
    }).end (err, sres) ->
      if err and err.message is 'Email is invalid.'
        suggestion = Mailcheck.run({ email: req.body.email })?.full
        msg = "Email is invalid."
        msg += " Did you mean #{suggestion}?" if suggestion
        if req.xhr
          res.send 403, { success: false, error: msg }
        else
          res.redirect opts.signupPagePath + "?error=#{msg}"
      else if err and req.xhr
        msg = err.response?.body?.error or err.message
        res.send 500, { success: false, error: msg }
      else if err
        next new Error err
      else
        next()

@beforeSocialAuth = (provider) -> (req, res, next) ->
  req.session.redirectTo = req.query['redirect-to']
  req.session.skipOnboarding = req.query['skip-onboarding']
  req.session.sign_up_intent = req.query['signup-intent']
  req.session.sign_up_referer = req.query['signup-referer']
  # accepted_terms_of_service and agreed_to_receive_emails use underscores
  req.session.accepted_terms_of_service = req.query['accepted_terms_of_service']
  req.session.agreed_to_receive_emails = req.query['agreed_to_receive_emails']
  options = { scope: 'email' }
  passport.authenticate(provider, options)(req, res, next)

@afterSocialAuth = (provider) -> (req, res, next) ->
  return next(new Error "#{provider} denied") if req.query.denied
  # Determine if we're linking the account and handle any Gravity errors
  # that we can do a better job explaining and redirecting for.
  providerName = _s.capitalize provider
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
    else if err?.message?.match 'Unauthorized source IP address'
      msg = "Your IP address was blocked by Facebook."
      res.redirect opts.loginPagePath + '?error=' + msg
    else if err?
      msg = err.message or err.toString?()
      res.redirect opts.loginPagePath + '?error=' + msg
    else if linkingAccount
      res.redirect opts.settingsPagePath
    else
      next()

@ensureLoggedInOnAfterSignupPage = (req, res, next) ->
  toLogin = "#{opts.loginPagePath}?redirect-to=#{opts.afterSignupPagePath}"
  res.redirect toLogin unless req.user?
  next()

@onError = (err, req, res, next) ->
  next err

@ssoAndRedirectBack = (req, res, next) ->
  return res.send { success: true, user: req.user.toJSON() } if req.xhr
  parsed = parse redirectBack req
  parsed = parse resolve opts.APP_URL, parsed.path unless parsed.hostname
  domain = parsed.hostname?.split('.').slice(1).join('.')
  return redirectBack(req, res) if domain isnt 'artsy.net'
  request
    .post "#{opts.ARTSY_URL}/api/v1/me/trust_token"
    .set { 'X-Access-Token': req.user.get 'accessToken' }
    .end (err, sres) ->
      return res.redirect parsed.href if err
      res.redirect "#{opts.ARTSY_URL}/users/sign_in" +
        "?trust_token=#{sres.body.trust_token}" +
        "&redirect_uri=#{parsed.href}"
