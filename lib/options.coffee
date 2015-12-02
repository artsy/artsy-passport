crypto = require 'crypto'

module.exports =
  linkedinPath: '/users/auth/linkedin'
  facebookPath: '/users/auth/facebook'
  twitterPath: '/users/auth/twitter'
  settingsPagePath: '/user/edit'
  loginPagePath: '/log_in'
  signupPagePath: '/sign_up'
  loginPath: '/users/sign_in'
  signupPath: '/users/invitation/accept'
  linkedinCallbackPath: '/users/auth/linkedin/callback'
  twitterCallbackPath: '/users/auth/twitter/callback'
  facebookCallbackPath: '/users/auth/facebook/callback'
  twitterLastStepPath: '/users/auth/twitter/email'
  logoutPath: '/users/sign_out'
  signupRedirect: '/personalize'
  userKeys: ['id', 'type', 'name', 'email', 'phone', 'lab_features',
    'default_profile_id', 'has_partner_access', 'collector_level']
  twitterSignupTempEmail: (token) ->
    hash = crypto.createHash('sha1').update(token).digest('hex')
    "#{hash.substr 0, 12}@artsy.tmp"
