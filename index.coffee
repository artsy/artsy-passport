#
# Uses [passport.js](http://passportjs.org/) to setup authentication with
# various providers like direct login with Artsy, or oauth signin with Facebook
# or Twitter.
#

_ = require 'underscore'
request = require 'superagent'
express = require 'express'
passport = require 'passport'
FacebookStrategy = require('passport-facebook').Strategy
TwitterStrategy = require('passport-twitter').Strategy
LocalStrategy = require('passport-local').Strategy
qs = require 'querystring'
crypto = require 'crypto'
csrf = require 'csurf'
{ parse } = require 'url'

# Alias sha1 hashing
hash = (str) ->
  crypto.createHash('sha1').update(str).digest('hex')

# Default options
opts =
  facebookPath: '/users/auth/facebook'
  twitterPath: '/users/auth/twitter'
  settingsPagePath: '/user/edit'
  loginPagePath: '/log_in'
  signupPagePath: '/sign_up'
  loginPath: '/users/sign_in'
  signupPath: '/users/invitation/accept'
  twitterCallbackPath: '/users/auth/twitter/callback'
  facebookCallbackPath: '/users/auth/facebook/callback'
  twitterLastStepPath: '/users/auth/twitter/email'
  logoutPath: '/users/sign_out'
  signupRedirect: '/'
  userKeys: ['id', 'type', 'name', 'email', 'phone', 'lab_features',
    'default_profile_id', 'has_partner_access', 'collector_level']
  twitterSignupTempEmail: (token) -> "#{hash(token).substr 0, 12}@artsy.tmp"

#
# Initialization that sets up our mountable express app  & runs Passport config.
#
module.exports = (options) =>
  module.exports.options = _.extend opts, options
  initPassport()
  initApp()
  app

module.exports.app = app = express()

initApp = ->
  app.use passport.initialize(), passport.session()
  app.get '*', csrf(cookie: true)
  app.post opts.loginPath, csrf(cookie: true), localAuth, afterLocalAuth
  app.post opts.signupPath, signup, passport.authenticate('local'),
    afterLocalAuth
  app.get opts.twitterPath, beforeSocialAuth('twitter')
  app.get opts.facebookPath, beforeSocialAuth('facebook')
  app.get opts.twitterCallbackPath, afterSocialAuth('twitter'),
    socialSignup('twitter')
  app.get opts.facebookCallbackPath, afterSocialAuth('facebook'),
    socialSignup('facebook')
  app.get opts.twitterLastStepPath, loginBeforeTwitterLastStep
  app.get opts.logoutPath, denyBadLogoutLinks, logout
  app.delete opts.logoutPath, logout
  app.post opts.twitterLastStepPath, submitTwitterLastStep, twitterLastStepError
  app.use headerLogin, trustTokenLogin, addLocals
  app.get '/', ensureEmailFromTwitterSignup

initPassport = ->
  passport.serializeUser serializeUser
  passport.deserializeUser deserializeUser
  passport.use new LocalStrategy(
    { usernameField: 'email', passReqToCallback: true }
    artsyCallback
  )
  passport.use new FacebookStrategy
    clientID: opts.FACEBOOK_ID
    clientSecret: opts.FACEBOOK_SECRET
    passReqToCallback: true
  , facebookCallback
  passport.use new TwitterStrategy
    consumerKey: opts.TWITTER_KEY
    consumerSecret: opts.TWITTER_SECRET
    passReqToCallback: true
  , twitterCallback

#
# Passport callbacks
#
artsyCallback = (req, username, password, done) ->
  request.get("#{opts.ARTSY_URL}/oauth2/access_token").query(
    client_id: opts.ARTSY_ID
    client_secret: opts.ARTSY_SECRET
    grant_type: 'credentials'
    email: username
    password: password
  ).end accessTokenCallback(req, done)

facebookCallback = (req, token, refreshToken, profile, done) ->
  # Link account
  if req.user
    request.post(
      "#{opts.ARTSY_URL}/api/v1/me/authentications/facebook"
    ).send(
      oauth_token: token
      access_token: req.user.get 'accessToken'
    ).end (err, res) -> done err, req.user
  # Login or signup
  else
    request.get("#{opts.ARTSY_URL}/oauth2/access_token").query(
      client_id: opts.ARTSY_ID
      client_secret: opts.ARTSY_SECRET
      grant_type: 'oauth_token'
      oauth_token: token
      oauth_provider: 'facebook'
    ).end accessTokenCallback(req, done,
      oauth_token: token
      provider: 'facebook'
      name: profile?.displayName
    )

twitterCallback = (req, token, tokenSecret, profile, done) ->
  # Link account
  if req.user
    request.post(
      "#{opts.ARTSY_URL}/api/v1/me/authentications/twitter"
    ).send(
      oauth_token: token
      oauth_token_secret: tokenSecret
      access_token: req.user.get 'accessToken'
    ).end (err, res) -> done err, req.user
  # Login or signup
  else
    request.get("#{opts.ARTSY_URL}/oauth2/access_token").query(
      client_id: opts.ARTSY_ID
      client_secret: opts.ARTSY_SECRET
      grant_type: 'oauth_token'
      oauth_token: token
      oauth_token_secret: tokenSecret
      oauth_provider: 'twitter'
    ).end accessTokenCallback(req, done,
      oauth_token: token
      oauth_token_secret: tokenSecret
      provider: 'twitter'
      email: opts.twitterSignupTempEmail(token, tokenSecret, profile)
      name: profile?.displayName
    )

accessTokenCallback = (req, done, params) -> (err, res) ->
  # Treat bad responses from Gravity as errors and get the most relavent
  # error message.
  if err and not res?.body or not err and res?.status > 400
    err = new Error "Gravity returned a generic #{res.status} html page"
  if not err and not res?.body.access_token?
    err = new Error "Gravity returned no access token and no error"
  msg = res?.body?.error_description or res?.body?.error or
        res?.text or err.stack or err.toString()
  # No errors—create the user from the access token.
  if not err
    done null, new opts.CurrentUser accessToken: res.body.access_token
  # If there's no user linked to this account, create the user via the POST
  # /user API. Then pass a custom error so our signup middleware can catch it,
  # login, and move on.
  else if msg.match 'no account linked'
    request
      .post(opts.ARTSY_URL + '/api/v1/user')
      .send(_.extend params, xapp_token: opts.XAPP_TOKEN)
      .end (err, res) ->
        done err or {
          message: 'artsy-passport: created user from social'
          user: res.body
        }
  # Invalid email or password.
  else if msg.match 'invalid email or password'
    done null, false, err
  # Unknown Exception.
  else
    console.warn "Error requesting an access token from Artsy", err
    done err

#
# Passport's serialize callbacks.
# Fetches and cachies some user data in the session.
#
serializeUser = (user, done) ->
  user.fetch
    success: ->
      keys = ['accessToken'].concat opts.userKeys
      done null, user.pick(keys)
    error: (m, e) -> done e.text

deserializeUser = (userData, done) ->
  done null, new opts.CurrentUser(userData)

#
# Middleware helpers to control the auth flow specific to Artsy and outside
# the scope of Passport.js.
#
localAuth = (req, res, next) ->
  passport.authenticate('local', (err, user, info) ->
    return req.login(user, next) if user
    res.authError = info
    next()
  )(req, res, next)

afterLocalAuth = (req, res ,next) ->
  if res.authError
    res.send 403, { success: false, error: res.authError }
  else if req.xhr and req.user?
    res.send { success: true, user: req.user.toJSON() }
  else if req.xhr and not req.user?
    res.send 500, { success: false, error: "Missing user." }
  else
    next()

beforeSocialAuth = (provider) -> (req, res, next) ->
  passport.authenticate(provider,
    scope: 'email'
    callbackURL: "#{opts.APP_URL}#{opts[provider + 'CallbackPath']}" +
                 "?#{qs.stringify req.query}"
  )(req, res, next)

afterSocialAuth = (provider) -> (req, res, next) ->
  return next(new Error "#{provider} denied") if req.query.denied
  linkingAccount = req.user?
  passport.authenticate(provider,
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
socialSignup = (provider) -> (err, req, res, next) ->
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

signup = (req, res, next) ->
  request.post(opts.ARTSY_URL + '/api/v1/user').send(
    name: req.body.name
    email: req.body.email
    password: req.body.password
    xapp_token: opts.XAPP_TOKEN
  ).end onCreateUser(next)

onCreateUser = (next) ->
  (err, res) ->
    if res.status isnt 201
      errMsg = res.body.message
    else
      errMsg = err?.text
    if errMsg then next(errMsg) else next()

#
# Middleware to add the user to app locals
#
addLocals = (req, res, next) ->
  if req.user
    res.locals.user = req.user
    res.locals.sd?.CURRENT_USER = req.user.toJSON()
  res.locals.sd?.APOPTS = res.locals.apopts = opts
  res.locals.sd?.CSRF_TOKEN = res.locals.csrfToken = req.csrfToken?()
  next()

#
# Middleware to allow log in by passing x-access-token in the headers or
# trust_token in the query params.
#
headerLogin = (req, res, next) ->
  return next() if req.path is opts.logoutPath
  if token = req.get('X-Access-Token') or req.query.access_token
    req.login new opts.CurrentUser(accessToken: token), next
  else
    next()

trustTokenLogin = (req, res, next) ->
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

#
# Twitter last step logic. Used to ensure we have an email from users that
# sign up with Twitter.
#
ensureEmailFromTwitterSignup = (req, res, next) ->
  return next() unless req.user?
  tmpSuffix = _.last(opts.twitterSignupTempEmail('').split('@'))
  if req.user.get('email').match tmpSuffix
    res.redirect opts.twitterLastStepPath
  else
    next()

loginBeforeTwitterLastStep = (req, res, next) ->
  return next() if req.user
  passport.authenticate('twitter',
    callbackURL: "#{opts.APP_URL}#{opts.twitterLastStepPath}"
  )(req, res, next)

submitTwitterLastStep = (req, res, next) ->
  return next "No user" unless req.user
  return next "No email provided" unless req.body.email?
  request.put("#{opts.ARTSY_URL}/api/v1/me").send(
    email: req.body.email
    email_confirmation: req.body.email
    access_token: req.user.get('accessToken')
  ).end (err, r) ->
    return next err if err
    # To work around an API caching bug we send another empty PUT and
    # update the current user.
    request.put("#{opts.ARTSY_URL}/api/v1/me").send(
      access_token: req.user.get('accessToken')
    ).end (err, r) ->
      return next err if err
      req.login req.user.set(r.body), (err) ->
        return next err if err
        res.redirect req.query['redirect-to'] or req.body['redirect-to'] or '/'

twitterLastStepError = (err, req, res, next) ->
  return next() if err.text?.match 'Error from MailChimp API'
  msg = err.response.body?.error or err.message or err.toString()
  if msg is 'User Already Exists'
    href = "#{opts.logoutPath}?redirect-to=#{opts.loginPagePath}"
    msg = "Artsy account already exists. If this is your Artsy email, please " +
          "<a href=#{opts.settingsPagePath}>delete this account</a>, then log" +
          " in to Artsy and link Twitter in your settings."
  res.redirect opts.twitterLastStepPath + '?error=' + msg

#
# Logout helpers.
#
denyBadLogoutLinks = (req, res, next) ->
  if parse(req.get 'Referrer').hostname.match 'artsy.net'
    next()
  else
    next new Error "Malicious logout link."

logout = (req, res, next) ->
  accessToken = req.user?.get('accessToken')
  req.logout()
  request
    .del("#{opts.ARTSY_URL}/api/v1/access_token")
    .send(access_token: accessToken)
    .end (error, response) ->
      if req.xhr
        res.status(200).send msg: 'success'
      else
        res.redirect req.query['redirect-to'] or '/'
