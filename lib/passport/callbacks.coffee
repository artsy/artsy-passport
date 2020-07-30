#
# Passport.js callbacks.
# These are functions that run after an OAuth flow, or after submitting a
# username/password form to login, signup, or link an account.
#

_ = require 'underscore'
request = require 'superagent'
opts = require '../options'
artsyXapp = require '@artsy/xapp'
ip = require 'ip'

resolveIPv4 = (ipAddress) ->
  if ip.isV6Format(ipAddress)? and ipAddress.indexOf('::ffff') >= 0
    return ipAddress.split('::ffff:')[1]
  return ipAddress

resolveProxies = (req) ->
  ipAddress = resolveIPv4(req.connection.remoteAddress)
  if req?.headers?["x-forwarded-for"]?
    return req.headers["x-forwarded-for"] + ", " + ipAddress
  else
    return ipAddress

@local = (req, username, password, otp, done) ->
  post = request
    .post("#{opts.ARTSY_URL}/oauth2/access_token")
    .set({ 'User-Agent': req.get 'user-agent' })
    .send({
      client_id: opts.ARTSY_ID
      client_secret: opts.ARTSY_SECRET
      grant_type: 'credentials'
      email: username
      password: password
      otp_attempt: otp
    })

  if req?.connection?.remoteAddress?
    post.set 'X-Forwarded-For', resolveProxies req

  post.end onAccessToken(req, done)

@facebook = (req, token, refreshToken, profile, done) ->
  req.socialProfileEmail = profile?.emails?[0]?.value
  # Link Facebook account
  if req.user
    request
      .post("#{opts.ARTSY_URL}/api/v1/me/authentications/facebook")
      .set({ 'User-Agent': req.get 'user-agent' })
      .send({
        oauth_token: token
        access_token: req.user.get 'accessToken'
      }).end (err, res) -> done err, req.user
  # Login or signup with Facebook
  else
    post = request
      .post("#{opts.ARTSY_URL}/oauth2/access_token")
      .set({ 'User-Agent': req.get 'user-agent' })
      .query({
        client_id: opts.ARTSY_ID
        client_secret: opts.ARTSY_SECRET
        grant_type: 'oauth_token'
        oauth_token: token
        oauth_provider: 'facebook'
      })

    if req?.connection?.remoteAddress?
      post.set 'X-Forwarded-For', resolveProxies req

    post.end onAccessToken(req, done, {
      oauth_token: token
      provider: 'facebook'
      name: profile?.displayName
    })

@apple = (req, accessToken, refreshToken, profile, done) ->

  displayName = null
  if profile.name
    displayName = profile.name.firstName + " " + profile.name.lastName

  # Link Apple account
  if req.user
    request
      .post("#{opts.ARTSY_URL}/api/v1/me/authentications/apple")
      .set({ 'User-Agent': req.get 'user-agent' })
      .send({
        name: displayName,
        email: profile.email,
        apple_uid: profile.id,
        oauth_token: accessToken
        access_token: req.user.get 'accessToken'
      }).end (err, res) -> done err, req.user
  else
    post = request
      .post("#{opts.ARTSY_URL}/oauth2/access_token")
      .set({ 'User-Agent': req.get 'user-agent' })
      .query({
        client_id: opts.ARTSY_ID
        client_secret: opts.ARTSY_SECRET
        grant_type: 'apple_uid'
        name: displayName,
        email: profile.email
        apple_uid: profile.id
      })

    if req?.connection?.remoteAddress?
      post.set 'X-Forwarded-For', resolveProxies req

    post.end onAccessToken(req, done, {
      provider: 'apple'
      apple_uid: profile.id
      name: displayName,
      email: profile.email
    })

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
    done null, new opts.CurrentUser { accessToken: res.body.access_token }
  # If there's no user linked to this account, create the user via the POST
  # /user API. Then attempt to fetch the access token again from Gravity and
  # recur back into this onAcccessToken callback.
  else if msg.match('no account linked')?
    if (req?.session? && params?)
      {
        sign_up_intent,
        sign_up_referer,
        agreed_to_receive_emails,
        accepted_terms_of_service
      } = req.session
      _.extend(
        params,
        { sign_up_intent, sign_up_referer, agreed_to_receive_emails, accepted_terms_of_service }
      )

    req.artsyPassportSignedUp = true
    request
      .post(opts.ARTSY_URL + '/api/v1/user')
      .send(params)
      .set({ 'User-Agent': req.get 'user-agent' })
      .set({ 'X-Xapp-Token': artsyXapp.token })
      .set({ 'Referer': req.get 'referer' })
      .end (err) ->
        return done err if err

        auth_params = {}
        if params.provider == 'apple'
          auth_params = _.extend params, {
            grant_type: 'apple_uid'
          }
        else
          auth_params = _.extend params, {
            grant_type: 'oauth_token'
            oauth_provider: params.provider
          }

        post = request
          .post("#{opts.ARTSY_URL}/oauth2/access_token")
          .set({ 'User-Agent': req.get 'user-agent' })
          .query(_.extend auth_params, {
            client_id: opts.ARTSY_ID
            client_secret: opts.ARTSY_SECRET
          })

        if req?.connection?.remoteAddress?
          post.set 'X-Forwarded-For', resolveProxies req

        post.end onAccessToken(req, done, params)
  # Uncaught Exception.
  else
    console.warn "Error requesting an access token from Artsy '#{msg}'"
    done err
