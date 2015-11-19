#
# Passport.js serialize/deserialize functions that turn user data
# into a session.
#

opts = require '../options'

@serialize = (user, done) ->
  user.fetch
    success: ->
      keys = ['accessToken'].concat opts.userKeys
      done null, user.pick(keys)
    error: (m, e) -> done e.text

@deserialize = (userData, done) ->
  done null, new opts.CurrentUser(userData)