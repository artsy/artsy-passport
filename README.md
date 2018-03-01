# Artsy Passport

[![CircleCI](https://circleci.com/gh/artsy/artsy-passport.svg?style=svg)](https://circleci.com/gh/artsy/artsy-passport)

Wires up the common auth handlers, and related security concerns, for Artsy's [Ezel](http://ezeljs.com)-based apps using [passport](http://passportjs.org/). Used internally at Artsy to DRY up authentication code.

## Breaking changes

We mave migrated this app from the module "artsy-passport" to "@artsy/passport", and called that v1.

## Setup

#### Make sure you first mount session, body parser, and start [artsy-xapp](https://github.com/artsy/artsy-xapp).

```coffee
app.use express.bodyParser()
app.use express.cookieParser('foobar')
app.use express.cookieSession()
artsyXapp.init -> app.listen()
```

#### Then mount Artsy Passport passing a big configuration hash.

_Values indicate defaults._

```coffee
app.use artsyPassport

  CurrentUser: # The CurrentUser Backbone model

  # Pass in env vars
  # ----------------
  FACEBOOK_ID: # Facebook app ID
  FACEBOOK_SECRET: # Facebook app secret
  TWITTER_KEY: # Twitter consumer key
  TWITTER_SECRET: # Twitter consumer secret
  TWITTER_KEY: # Twitter consumer key
  TWITTER_SECRET: # Twitter consumer secret
  LINKEDIN_KEY: # Linkedin app key
  LINKEDIN_SECRET: # Linkedin app secret
  ARTSY_ID: # Artsy client id
  ARTSY_SECRET: # Artsy client secret
  ARTSY_URL: # SSL Artsy url e.g. https://artsy.net
  APP_URL: # Url pointing back to your app e.g. http://flare.artsy.net
  SEGMENT_WRITE_KEY_SERVER: # Segment write key to track signup

  # Defaults you probably don't need to touch
  # -----------------------------------------

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

  # Landing pages
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
```

The keys are cased so it's convenient to pass in a configuration hash. A minimal setup could look like this:

```coffee
app.use artsyPassport _.extend config,
  CurrentUser: CurrentUser
```

**Note:** CurrentUser must be a Backbone model with typical `get` and `toJSON` methods.

#### Create a login form pointing to your paths.

```jade
h1 Login
pre!= error
a( href=ap.facebookPath ) Login via Facebook
a( href=ap.twitterPath ) Login via Twitter
form( action=ap.loginPagePath, method='POST' )
  h3 Login via Email
  input( name='name' )
  input( name='email' )
  input( name='password' )
  input( type="hidden" name="_csrf" value=csrfToken )
  button( type='submit' ) Login
```

#### And maybe a signup form...

```jade
h1 Signup
pre!= error
a( href=ap.facebookPath ) Signup via Facebook
a( href=ap.twitterPath ) Signup via Twitter
form( action=ap.signupPagePath, method='POST' )
  h3 Signup via Email
  input( name='name' )
  input( name='email' )
  input( name='password' )
  input( type="hidden" name="_csrf" value=csrfToken )
  button( type='submit' ) Signup
```

#### And maybe a settings page for linking accounts...

```jade
h2 Linked Accounts
pre!= error
- providers = user.get('authentications').map(function(a) { return a.provider })
if providers.indexOf('facebook') > -1
  | Connected Facebook
else
  a( href=ap.facebookPath ) Connect Facebook
br
if providers.indexOf('twitter') > -1
  | Connected Twitter
else
  a( href=ap.twitterPath ) Connect Twitter
br
if providers.indexOf('linkedin') > -1
  | Connected LinkedIn
else
  a( href=ap.linkedinPath ) Connect LinkedIn
```

#### Finally there's this weird "one last step" UI for twitter to store emails after signup.

```jade
h1 Just one more step
pre!= error
form( method='post', action=ap.twitterLastStepPath )
  input( type="hidden" name="_csrf" value=csrfToken )
  input.bordered-input( name='email' )
  button( type='submit' ) Join Artsy
```

#### Render the pages

```coffee
{ loginPagePath, signupPagePath, settingsPagePath,
  afterSignupPagePath, twitterLastStepPath } = artsyPassport.options

app.get loginPagePath, (req, res) -> res.render 'login'
app.get signupPagePath, (req, res) -> res.render 'signup'
app.get settingsPagePath, (req, res) -> res.render 'settings'
app.get afterSignupPagePath, (req, res) -> res.render 'personalize'
app.get twitterLastStepPath, (req, res) -> res.render 'twitter_last_step'
```

#### Access a logged in Artsy user in a variety of ways...

In your server-side templates

```jade
h1 Hello #{user.get('name')}
```

In your client-side code

```coffee
CurrentUser = require '../models/current_user.coffee'
sd = require('sharify').data

user = new CurrentUser(sd.CURRENT_USER)
```

In your routers

```coffee
app.get '/', (req, res) ->
  res.send 'Hello ' + req.user.get('name')
```

_These forms of user will be null if they're not logged in._

## Sanitize Redirect

If you implement a fancier auth flow that involves client-side redirecting back, you may find this helper useful in avoiding ["open redirect"](https://github.com/artsy/artsy-passport/issues/68) attacks.

```coffee
sanitizeRedirect = require 'artsy-passport/sanitize-redirect'

location.href = sanitizeRedirect "http://artsy.net%0D%0Aattacker.com/"
# Notices the url isn't pointing at artsy.net, so just redirects to /
```

## Contributing

Add a `local.artsy.net` entry into your /etc/hosts

```
127.0.0.1 localhost
#...
127.0.0.1 local.artsy.net
```

Install node modules `npm install` then write a ./config.coffee that looks something like this:

```coffee
module.exports =
  FACEBOOK_ID: ''
  FACEBOOK_SECRET: ''
  TWITTER_KEY: ''
  TWITTER_SECRET: ''
  LINKEDIN_KEY: ''
  LINKEDIN_SECRET: ''
  ARTSY_ID: ''
  ARTSY_SECRET: ''
  ARTSY_URL: 'https://api.artsy.net'
  APP_URL: 'http://local.artsy.net:4000'
  # An Artsy user that's linked to Facebook and Twitter
  ARTSY_EMAIL: 'craig@artsy.net'
  ARTSY_PASSWORD: ''
  TWITTER_EMAIL: 'craigspaeth@gmail.com'
  TWITTER_PASSWORD: ''
  FACEBOOK_EMAIL: 'craigspaeth@gmail.com'
  FACEBOOK_PASSWORD: ''
```

Then you can check the example by running `npm run example` and opening [localhost:4000](http://localhost:4000).

The tests are a combination of integration and middleware unit tests. To run the whole suite use `npm test`.
