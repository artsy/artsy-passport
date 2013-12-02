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

Mount middlware passing a big configuration hash like so below (the values indicate defaults).

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
  twitterCallback: '/auth/twitter/callback' # After twitter auth callback url
  facebookCallback: '/auth/facebook/callback' # After facebook auth callback url
  currentUserModel: # Backbone Model class to serialize the user into e.g. `CurrentUser`
  sharifyData: # Pass in your app's sharify data e.g. `require('sharify').data`
````

The keys are cased so it's convenient to pass in a configuration hash. A minimal setup could look like this:

````coffeescript
app.use artsyAuth _.extend config,
  currentUserModel: CurrentUser
  sharifyData: sharify.data
````

Point your view to the proper paths:

````jade
h1 Login
a( href='/users/auth/facebook' ) Login via Facebook
a( href='/users/auth/twitter' ) Login via Twitter
form( action='/users/sign_in', method='POST' )
  h1 Login via Email
  input( name='email' )
  input( name='password' )
  button( type='submit' ) Login

h1 Signup
a( href='/users/auth/facebook?sign_up=true' ) Login via Facebook
a( href='/users/auth/twitter?sign_up=true' ) Login via Twitter
form( action='/users/invitation/accept', method='POST' )
  h1 Signup
  input( name='email' )
  input( name='password' )
  button( type='submit' ) Login
````

Handle the request after logging in or signing up.

````coffeescript
app.use artsyPassport #...
app.post '/users/sign_in', (req, res) ->
  req.redirect '/'
app.post '/users/invitation/accept', (req, res) ->
  req.redirect '/personalize'
app.get '/auth/twitter/callback', (req, res) ->
  if req.params.sign_up then res.redirect('/personalize') else req.redirect '/'
app.get '/auth/facebook/callback', (req, res) ->
  if req.params.sign_up then res.redirect('/personalize') else req.redirect '/'
````