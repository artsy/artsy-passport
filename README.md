# Artsy Passport

Wires up the common auth handlers for Artsy's [Ezel](http://ezeljs.com)-based apps using [passport](http://passportjs.org/). Used internally at Artsy to DRY up authentication code.

## Setup

#### Make sure you first mount session, body parser, and start [artsy-xapp](https://github.com/artsy/artsy-xapp).

````coffeescript
app.use express.bodyParser()
app.use express.cookieParser('foobar')
app.use express.cookieSession()
artsyXapp.init -> app.listen()
````

#### Then mount Artsy Passport passing a big configuration hash.

_Values indicate defaults._

````coffeescript
app.use artsyPassport

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
````

The keys are cased so it's convenient to pass in a configuration hash. A minimal setup could look like this:

````coffeescript
app.use artsyPassport _.extend config,
  CurrentUser: CurrentUser
````

**Note:** CurrentUser must be a Backbone model with typical `get` and `toJSON` methods.

#### Create a login form pointing to your paths.

````jade
h1 Login
.error!= error
a( href='/users/auth/facebook' ) Login via Facebook
a( href='/users/auth/twitter' ) Login via Twitter
form( action='/users/sign_in', method='POST' )
  h3 Login via Email
  input( name='name' )
  input( name='email' )
  input( name='password' )
  input( type="hidden" name="_csrf" value=csrfToken )
  button( type='submit' ) Signup
````

#### And maybe a signup form...

````jade
h1 Signup
.error!= error
a( href='/users/auth/facebook?sign_up=true' ) Signup via Facebook
a( href='/users/auth/twitter?sign_up=true' ) Signup via Twitter
form( action='/users/invitation/accept', method='POST' )
  h3 Signup via Email
  input( name='name' )
  input( name='email' )
  input( name='password' )
  button( type='submit' ) Signup
````

#### And maybe a settings page for linking accounts...

````jade
h1 Linked Accounts
.error!= error
- providers = user.get('authentications').map(function(a) { return a.provider })
if providers.indexOf('facebook') > 0
  a( href='/users/auth/facebook' ) Connect Facebook
else
  | Connected Facebook
if providers.indexOf('twitter') > 0
  a( href='/users/auth/twitter' ) Connect Twitter
else
  | Connected Twitter
if providers.indexOf('linkedin') > 0
  a( href='/users/auth/linkedin' ) Connect LinkedIn
else
  | Connected LinkedIn
````

#### Finally there's this weird "one last step" UI for twitter to store emails after signup.

````jade
h1 Just one more step
.error!= error
form( method='post', action='/users/auth/twitter/email' )
  input.bordered-input( name='email' )
  button( type='submit' ) Join Artsy
````

#### Render the pages

````coffeescript
{ loginPagePath, signupPagePath, settingsPagePath,
  afterSignupPagePath, twitterLastStepPath } = artsyPassport.options

app.get loginPagePath, (req, res) -> res.render 'login'
app.get signupPagePath, (req, res) -> res.render 'signup'
app.get settingsPagePath, (req, res) -> res.render 'settings'
app.get afterSignupPagePath, (req, res) -> res.render 'personalize'
app.get twitterLastStepPath, (req, res) -> res.render 'twitter_last_step'
````

#### Access a logged in Artsy user in a variety of ways...

In your server-side templates

````jade
h1 Hello #{user.get('name')}
````

In your client-side code

````coffeescript
CurrentUser = require '../models/current_user.coffee'
sd = require('sharify').data

user = new CurrentUser(sd.CURRENT_USER)
````

In your routers

````coffeescript
app.get '/', (req, res) ->
  res.send 'Hello ' + req.user.get('name')
````

_These forms of user will be null if they're not logged in._

## Contributing

Add a `local.artsy.net` entry into your /etc/hosts

````
127.0.0.1 localhost
#...
127.0.0.1 local.artsy.net
````

Install node modules `npm install` then write a ./config.coffee that looks something like this:

````coffeescript
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
  APP_URL: 'http://local.artsy.net:3000'
  # An Artsy user that's linked to Facebook and Twitter
  ARTSY_EMAIL: 'craig@artsy.net'
  ARTSY_PASSWORD: ''
  TWITTER_EMAIL: 'craigspaeth@gmail.com'
  TWITTER_PASSWORD: ''
  FACEBOOK_EMAIL: 'craigspaeth@gmail.com'
  FACEBOOK_PASSWORD: ''
````

Then you can check the example by running `make example` and opening [localhost:3000](http://localhost:3000).

The tests are a combination of integration and middleware unit tests. To run the whole suite use `make test`.
