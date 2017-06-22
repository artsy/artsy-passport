#
# Passport.js serialize/deserialize functions that turn user data
# into a session.
#

_ = require 'underscore'
opts = require '../options.coffee'
request = require 'superagent'
async = require 'async'

module.exports.serialize = (user, done) ->
  async.parallel [
    (cb) ->
      request
        .get("#{opts.ARTSY_URL}/api/v1/me")
        .set('X-Access-Token': user.get 'accessToken').end(cb)
    (cb) ->
      request
        .get("#{opts.ARTSY_URL}/api/v1/me/authentications")
        .set('X-Access-Token': user.get 'accessToken').end(cb)
  ], (err, results) ->
    return done err if err
    [{ body: userData },{ body: authsData }] = results
    user.set(userData).set(authentications: authsData)
    keys = ['accessToken', 'authentications'].concat opts.userKeys
    done null, user.pick(keys)

module.exports.deserialize = (userData, done) ->
  done null, new opts.CurrentUser(userData)
