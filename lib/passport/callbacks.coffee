#
# Passport.js callbacks.
# These are functions that run after an OAuth flow, or after submitting a
# username/password form to login, signup, or link an account.
#

_ = require 'underscore'
request = require 'superagent'
opts = require '../options'
artsyXapp = require 'artsy-xapp'

@local = (req, username, password, done) ->
  request
    .post("#{opts.ARTSY_URL}/oauth2/access_token")
    .set('User-Agent': req.get 'user-agent')
    .query(
      client_id: opts.ARTSY_ID
      client_secret: opts.ARTSY_SECRET
      grant_type: 'credentials'
      email: username
      password: password
    ).end onAccessToken(req, done)

@linkedin = (req, token, tokenSecret, profile, done) ->
  req.socialProfileEmail = profile?.emails?[0]?.value
  # Link Linkedin account
  if req.user
    request
      .post("#{opts.ARTSY_URL}/api/v1/me/authentications/linkedin")
      .set('User-Agent': req.get 'user-agent')
      .send(
        oauth_token: token
        oauth_token_secret: tokenSecret
        access_token: req.user.get 'accessToken'
      ).end (err, res) -> done err, req.user
  # Login with Linkedin account
  else
    request
      .post("#{opts.ARTSY_URL}/oauth2/access_token")
      .set('User-Agent': req.get 'user-agent')
      .query(
        client_id: opts.ARTSY_ID
        client_secret: opts.ARTSY_SECRET
        grant_type: 'oauth_token'
        oauth_token: token
        oauth_token_secret: tokenSecret
        oauth_provider: 'linkedin'
      ).end onAccessToken(req, done,
        oauth_token: token
        oauth_token_secret: tokenSecret
        provider: 'linkedin'
      )

@facebook = (req, token, refreshToken, profile, done) ->
  req.socialProfileEmail = profile?.emails?[0]?.value
  # req.socialProfileEmail = profile
  # Link Facebook account
  if req.user
    request
      .post("#{opts.ARTSY_URL}/api/v1/me/authentications/facebook")
      .set('User-Agent': req.get 'user-agent')
      .send(
        oauth_token: token
        access_token: req.user.get 'accessToken'
      ).end (err, res) -> done err, req.user
  # Login or signup with Facebook
  else
    request
      .post("#{opts.ARTSY_URL}/oauth2/access_token")
      .set('User-Agent': req.get 'user-agent')
      .query(
        client_id: opts.ARTSY_ID
        client_secret: opts.ARTSY_SECRET
        grant_type: 'oauth_token'
        oauth_token: token
        oauth_provider: 'facebook'
      ).end onAccessToken(req, done,
        oauth_token: token
        provider: 'facebook'
        name: profile?.displayName
      )

@twitter = (req, token, tokenSecret, profile, done) ->
  # Link Twitter account
  if req.user
    request
      .post("#{opts.ARTSY_URL}/api/v1/me/authentications/twitter")
      .set('User-Agent': req.get 'user-agent')
      .send(
        oauth_token: token
        oauth_token_secret: tokenSecret
        access_token: req.user.get 'accessToken'
      ).end (err, res) -> done err, req.user
  # Login or signup with Twitter
  else
    request
      .post("#{opts.ARTSY_URL}/oauth2/access_token")
      .set('User-Agent': req.get 'user-agent')
      .query(
        client_id: opts.ARTSY_ID
        client_secret: opts.ARTSY_SECRET
        grant_type: 'oauth_token'
        oauth_token: token
        oauth_token_secret: tokenSecret
        oauth_provider: 'twitter'
      ).end onAccessToken(req, done,
        oauth_token: token
        oauth_token_secret: tokenSecret
        provider: 'twitter'
        email: opts.twitterSignupTempEmail(token, tokenSecret, profile)
        name: profile?.displayName
      )

onAccessToken = (req, done, params) -> (err, res) ->
  # Treat bad responses from Gravity as errors and get the most relavent
  # error message.
  if err and not res?.body or not err and res?.status > 400
    err = new Error "Gravity returned a generic #{res.status} html page"
  if not err and not res?.body.access_token?
    err = new Error "Gravity returned no access token and no error"
  err?.message = msg = res?.body?.error_description or res?.body?.error or
    res?.text or err.stack or err.toString()
  # No errors—create the user from the access token.
  if not err
    done null, new opts.CurrentUser accessToken: res.body.access_token
  else if params?.provider is 'twitter' and msg.match('no account linked')?
    err = new Error "No Twitter account found, please sign up"
    done err
  # If there's no user linked to this account, create the user via the POST
  # /user API. Then attempt to fetch the access token again from Gravity and
  # recur back into this onAcccessToken callback.
  else if msg.match('no account linked')?
    if (req?.session?.signupIntent && params?) then params.sign_up_intent = req.session.signupIntent
    req.artsyPassportSignedUp = true
    request
      .post(opts.ARTSY_URL + '/api/v1/user')
      .send(params)
      .set('User-Agent': req.get 'user-agent')
      .set('X-Xapp-Token': artsyXapp.token)
      .end (err) ->
        return done err if err
        request
          .post("#{opts.ARTSY_URL}/oauth2/access_token")
          .set('User-Agent': req.get 'user-agent')
          .query(_.extend params,
            client_id: opts.ARTSY_ID
            client_secret: opts.ARTSY_SECRET
            grant_type: 'oauth_token'
            oauth_provider: params.provider
          ).end onAccessToken(req, done, params)
  # Uncaught Exception.
  else
    console.warn "Error requesting an access token from Artsy '#{msg}'"
    done err
