const _ = require('underscore');
const _s = require('underscore.string');
const opts = require('../options');

module.exports = function(req, res, next) {
  if (req.user) {
    res.locals.user = req.user;
    if (res.locals.sd != null) {
      res.locals.sd.CURRENT_USER = req.user.toJSON();
    }
  }
  if (res.locals.sd != null) {
    res.locals.csrfToken = typeof req.csrfToken === 'function' ? req.csrfToken() : undefined;
    res.locals.sd.CSRF_TOKEN = res.locals.csrfToken;
  }
  if (res.locals.sd != null) {
    res.locals.error = _s.escapeHTML(req.query.error);
    res.locals.sd.ERROR = res.locals.error;
  }
  if (res.locals.sd != null) {
    res.locals.ap = _.pick(
      opts,
      'applePath',
      'appleCallbackPath',
      'facebookPath',
      'facebookCallbackPath',
      'loginPagePath',
      'signupPagePath',
      'settingsPagePath',
      'afterSignupPagePath',
      'logoutPath'
    );
    res.locals.sd.AP = res.locals.ap;
  }
  next();
};