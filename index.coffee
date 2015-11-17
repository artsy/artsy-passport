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
  app.get opts.twitterPath, socialAuth('twitter')
  app.get opts.facebookPath, socialAuth('facebook')
  app.get opts.twitterCallbackPath, socialAuth('twitter'),
    socialSignup('twitter')
  app.get opts.facebookCallbackPath, socialAuth('facebook'),
    socialSignup('facebook')
  app.get opts.twitterLastStepPath, loginBeforeTwitterLastStep
  app.delete opts.logoutPath, logout
  app.post opts.twitterLastStepPath, submitTwitterLastStep
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
    callbackURL: "#{opts.APP_URL}#{opts.facebookCallbackPath}"
    passReqToCallback: true
    state: true
  , facebookCallback
  passport.use new TwitterStrategy
    consumerKey: opts.TWITTER_KEY
    consumerSecret: opts.TWITTER_SECRET
    callbackURL: "#{opts.APP_URL}#{opts.twitterCallbackPath}"
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
  if req.user
    request.post(
      "#{opts.ARTSY_URL}/api/v1/me/authentications/facebook"
    ).query(
      oauth_token: token
      access_token: req.user.get 'accessToken'
    ).end (res) ->
      err = res.body.error or res.body.message + ': Facebook' if res.error
      done err, req.user
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
  if req.user
    request.post(
      "#{opts.ARTSY_URL}/api/v1/me/authentications/twitter"
    ).query(
      oauth_token: token
      oauth_token_secret: tokenSecret
      access_token: req.user.get 'accessToken'
    ).end (res) ->
      err = res.body.error or res.body.message + ': Twitter' if res.error
      done err, req.user
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

accessTokenCallback = (req, done, params) ->
  return (e, res) ->
    # Catch the various forms of error Artsy could encounter
    err = null
    try
      err = JSON.parse(res.text).error_description
      err ?= JSON.parse(res.text).error
    err ?= res.body.error_description if res?.body.error_description?
    err ?= "Artsy returned a generic #{res.status}" if res?.status > 400
    unless res?.body.access_token?
      err ?= "Artsy returned no access token and no error"
    err ?= e
    # If there are no errors create the user from the access token
    unless err
      return done(null, new opts.CurrentUser(accessToken: res.body.access_token))
    # If there's no user linked to this account, create the user via the POST
    # /user API. Then pass a custom error so our signup middleware can catch it,
    # login, and move on.
    if err?.match?('no account linked')
      params.xapp_token = opts.XAPP_TOKEN
      request
        .post(opts.ARTSY_URL + '/api/v1/user')
        .send(params)
        .end (err, res) ->
          req.session.redirectTo = opts.signupRedirect
          err = (err or res?.body.error_description or res?.body.error)
          done err or {
            message: 'artsy-passport: created user from social'
            user: res.body
          }
    # Invalid email or password
    else if err.match?('invalid email or password')
      done null, false, err
    # Other errors
    else
      console.warn "Error requesting an access token from Artsy: \n\n" +
        res?.text
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

socialAuth = (provider) ->
  (req, res, next) ->
    return next("#{provider} denied") if req.query.denied
    # CSRF protection for Facebook account linking
    if req.path is opts.facebookPath and req.user and
       req.query.state isnt hash(req.user.get 'accessToken')
      err = new Error("Must pass a `state` query param equal to a sha1 hash" +
        "of the user's access token to link their account.")
      return next err
    # Twitter OAuth 1 doesn't support `state` param csrf out of the box.
    # So we implement it ourselves ( -__- )
    # https://twittercommunity.com/t/is-the-state-parameter-supported/1889
    if provider is 'twitter' and not req.query.state
      console.log 'set state', req.path
      req.session.twitterState = hash Math.random().toString()
    if req.path is opts.twitterCallbackPath and req.query.state isnt req.session.twitterState
      console.log 'check state', req.path
      err = new Error("Must pass a valid `state` param.")
      return next err
    passport.authenticate(provider,
      scope: 'email'
      callbackURL: "#{opts.APP_URL}#{opts.twitterCallbackPath}?state=#{req.session.twitterState}" if provider is 'twitter'
    )(req, res, next)

# We have to hack around passport by capturing a custom error message that
# indicates we've created a user in one of passport's social callbacks. If we
# catch that error then we'll attempt to redirect back to login and strip out
# the expired Facebook/Twitter credentials.
socialSignup = (provider) ->
  (err, req, res, next) ->
    unless err.message is 'artsy-passport: created user from social'
      return next(err)
    # Redirect to a social login url stripping out the Facebook/Twitter
    # credentials (code, oauth_token, etc). This will be seemless for Facebook,
    # but since Twitter has a ask for permision UI it will mean asking
    # permission twice. It's not apparent yet why we can't re-use the
    # credentials... without stripping them we get errors from FB & Twitter.
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
  ).end (r) ->
    err = r.error or r.body?.error_description or r.body?.error
    err = null if r.text.match 'Error from MailChimp API'
    return next err if err
    # To work around an API caching bug we send another empty PUT and
    # update the current user.
    request.put("#{opts.ARTSY_URL}/api/v1/me").send(
      access_token: req.user.get('accessToken')
    ).end (r2) ->
      err = r.error or r.body?.error_description or r.body?.error
      err = null if r.text.match 'Error from MailChimp API'
      return next err if err
      req.login req.user.set(r2.body), (err) ->
        return next err if err
        res.redirect req.query['redirect-to'] or req.body['redirect-to'] or '/'

#
# Logout helpers.
#
destroyAccessToken = (next, accessToken) ->
  if accessToken
    request
      .del("#{opts.ARTSY_URL}/api/v1/access_token")
      .send(access_token: accessToken)
      .end (error, response) ->
        next()
  else
    next()

logout = (req, res, next) ->
  accessToken = req.user?.get('accessToken')
  req.logout()
  destroyAccessToken(next, accessToken)
