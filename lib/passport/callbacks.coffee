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
  request.get("#{opts.ARTSY_URL}/oauth2/access_token").query(
    client_id: opts.ARTSY_ID
    client_secret: opts.ARTSY_SECRET
    grant_type: 'credentials'
    email: username
    password: password
  ).end onAccessToken(req, done)

@linkedin = (req, token, tokenSecret, profile, done) ->
  # Link Linkedin account
  if req.user
    request.post(
      "#{opts.ARTSY_URL}/api/v1/me/authentications/linkedin"
    ).query(
      oauth_token: token
      oauth_token_secret: tokenSecret
      access_token: req.user.get 'accessToken'
    ).end (res) ->
      err = res.body.error or res.body.message + ': LinkedIn' if res.error
      done err, req.user
  # Login with Linkedin account
  else
    request.get("#{opts.ARTSY_URL}/oauth2/access_token").query(
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
      name: profile?.displayName
    )

@facebook = (req, token, refreshToken, profile, done) ->
  # Link Facebook account
  if req.user
    request.post(
      "#{opts.ARTSY_URL}/api/v1/me/authentications/facebook"
    ).send(
      oauth_token: token
      access_token: req.user.get 'accessToken'
    ).end (err, res) -> done err, req.user
  # Login or signup with Facebook
  else
    request.get("#{opts.ARTSY_URL}/oauth2/access_token").query(
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
    request.post(
      "#{opts.ARTSY_URL}/api/v1/me/authentications/twitter"
    ).send(
      oauth_token: token
      oauth_token_secret: tokenSecret
      access_token: req.user.get 'accessToken'
    ).end (err, res) -> done err, req.user
  # Login or signup with Twitter
  else
    request.get("#{opts.ARTSY_URL}/oauth2/access_token").query(
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
  msg = res?.body?.error_description or res?.body?.error or
        res?.text or err.stack or err.toString()
  # No errors—create the user from the access token.
  if not err
    done null, new opts.CurrentUser accessToken: res.body.access_token
  # If there's no user linked to this account, create the user via the POST
  # /user API. Then pass a custom error so our signup middleware can catch it,
  # login, and move on.
  else if msg.match('no account linked')?
    request
      .post(opts.ARTSY_URL + '/api/v1/user')
      .send(_.extend params)
      .set('X-Xapp-Token': artsyXapp.token)
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
