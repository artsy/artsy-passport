crypto = require 'crypto'

module.exports =

  # Local auth
  loginPath: '/users/sign_in'
  signupPath: '/users/invitation/accept'
  linkedinPath: '/users/auth/linkedin'

  # Social auth
  linkedinPath: '/users/auth/linkedin'
  linkedinCallbackPath: '/users/auth/linkedin/callback'
  facebookPath: '/users/auth/facebook'
  facebookCallbackPath: '/users/auth/facebook/callback'
  twitterPath: '/users/auth/twitter'
  twitterCallbackPath: '/users/auth/twitter/callback'
  twitterLastStepPath: '/users/auth/twitter/email'
  twitterSignupTempEmail: (token) ->
    hash = crypto.createHash('sha1').update(token).digest('hex')
    "#{hash.substr 0, 12}@artsy.tmp"

  # Landing page paths
  loginPagePath: '/log_in'
  signupPagePath: '/sign_up'
  settingsPagePath: '/user/edit'
  afterSignupPagePath: '/personalize'

  # Misc
  logoutPath: '/users/sign_out'
  userKeys: [
    'id', 'type', 'name', 'email', 'phone', 'lab_features',
    'default_profile_id', 'has_partner_access', 'collector_level'
  ]
