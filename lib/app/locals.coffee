_ = require 'underscore'
_s = require 'underscore.string'
opts = require '../options.coffee'

module.exports = (req, res, next) ->
  if req.user
    res.locals.user = req.user
    res.locals.sd?.CURRENT_USER = req.user.toJSON()
  res.locals.sd?.CSRF_TOKEN = res.locals.csrfToken = req.csrfToken?()
  res.locals.sd?.ERROR = res.locals.error = _s.escapeHTML req.query.error
  res.locals.sd?.AP = res.locals.ap = _.pick opts, 'linkedinPath',
    'linkedinCallbackPath','facebookPath','facebookCallbackPath','twitterPath',
    'twitterCallbackPath','twitterLastStepPath','twitterSignupTempEmail',
    'loginPagePath','signupPagePath','settingsPagePath','afterSignupPagePath',
    'logoutPath'
  next()
