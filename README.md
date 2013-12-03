# artsy-passport

Wires up the common auth handlers for Artsy's [Ezel](ezeljs.com)-based apps using [passport](http://passportjs.org/). Used internally at Artsy to DRY up authentication code.

## Features

* Authenticates with Facebook and Twitter
* Fetches the current user and caches their JSON data in the session
* Serializes `req.user` into a backbone model populated by the cached user JSON
* Provides endpoints to ajax POST for signup and login
* Bootstraps the current user as `sd.CURRENT_USER` in [sharify](https://github.com/artsy/sharify) data
* Signup routes that create the user and log them in to `req.user`
* Redirects to / after Twitter/Facebook login

## Example

#### Make sure you're using session, body parser, and [xapp](https://github.com/artsy/artsy-xapp-middleware) middlware.

````coffeescript
app.use require('artsy-xapp-middlware') { #... }
app.use express.bodyParser()
app.use express.cookieParser('foobar')
app.use express.cookieSession()
````

#### Then mount artsyPassport passing a big configuration hash like so below (the values indicate defaults).

````coffeescript
app.use artsyPassport
  FACEBOOK_ID: # Facebook app ID
  FACEBOOK_SECRET: # Facebook app secret
  TWITTER_KEY: # Twitter consumer key
  TWITTER_SECRET: # Twitter consumer secret
  ARTSY_ID: # Artsy client id
  ARTSY_SECRET: # Artsy client secret
  SECURE_URL: # SSL Artsy url e.g. https://artsy.net
  APP_URL: # Url pointing back to your app e.g. http://flare.artsy.net
  facebookPath: '/users/auth/facebook' # Url to point your facebook button to
  twitterPath: '/users/auth/twitter' # Url to point your twitter button to
  loginPath: '/users/sign_in' # POST `email` and `password` to this path to login
  signupPath: '/users/invitation/accept' # POST `email` and `password` to this path to signup
  twitterCallbackPath: '/auth/twitter/callback' # After twitter auth callback url
  facebookCallbackPath: '/auth/facebook/callback' # After facebook auth callback url
  CurrentUser: # Backbone Model class to serialize the user into e.g. `CurrentUser`
  sharifyData: # Pass in your app's sharify data e.g. `require('sharify').data`
````

The keys are cased so it's convenient to pass in a configuration hash. A minimal setup could look like this:

````coffeescript
app.use artsyPassport _.extend config,
  CurrentUser: CurrentUser
  sharifyData: sharify.data
````

#### Conveniently access your artsyPassport paths through the `artsyPassport` view local and `ARTSY_PASSPORT` sharify data to populate your forms.

````jade
h1 Login
a( href=artsyPassport.facebookPath ) Login via Facebook
a( href=artsyPassport.twitterPath ) Login via Twitter
form( action=artsyPassport.loginPath, method='POST' )
  h3 Login via Email
  input( name='email' )
  input( name='password' )
  button( type='submit' ) Login

h1 Signup
a( href=artsyPassport.facebookPath + '?sign_up=true' ) Signup via Facebook
a( href=artsyPassport.twitterPath + '?sign_up=true' ) Signup via Twitter
form( action=artsyPassport.signupPath, method='POST' )
  h3 Signup via Email
  input( name='name' )
  input( name='email' )
  input( name='password' )
  button( type='submit' ) Signup
````

#### Handle login and signup callbacks.

````coffeescript
{ loginPath, signupPath, twitterCallbackPath,
  facebookCallbackPath } = artsyPassport.options

# Artsy passport route handlers
app.post loginPath, (req, res) ->
  res.redirect '/'
app.post signupPath, (req, res) ->
  res.redirect '/personalize'
app.get twitterCallbackPath, (req, res) ->
  if req.query.sign_up then res.redirect('/personalize') else res.redirect('/')
app.get facebookCallbackPath, (req, res) ->
  if req.query.sign_up then res.redirect('/personalize') else res.redirect('/')
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
  res.send req.user?.get('name')
````

## Contributing

First install node modules `npm install`. Then run tests `make test`, or run the example. This is a basic implementation of artsyPassport, to use this you first need to write an example/config.coffee that looks something like this:

````coffeescript
module.exports =
  FACEBOOK_ID: ''
  FACEBOOK_SECRET: ''
  TWITTER_KEY: ''
  TWITTER_SECRET: ''
  ARTSY_ID: ''
  ARTSY_SECRET: ''
  SECURE_URL: 'https://staging.artsy.net'
  APP_URL: 'http://localhost:4000'
````

Then you can check the example by running `make example` and opening [localhost:4000](http://localhost:4000).