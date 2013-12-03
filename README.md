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

Make sure you're using a session, body parser,and [xapp](https://github.com/artsy/artsy-xapp-middleware) middlware. Then mount artsyPassport passing a big configuration hash like so below (the values indicate defaults).

````coffeescript
app.use require('artsy-xapp-middlware') { #... }
app.use express.bodyParser()
app.use express.cookieParser('foobar')
app.use express.cookieSession()
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

Point your view forms to the proper paths:

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
  input( name='name' )
  input( name='email' )
  input( name='password' )
  button( type='submit' ) Login
````

Handle the request after logging in or signing up.

````coffeescript
# Setup Artsy Passport
app.use artsyPassport _.extend config,
  CurrentUser: CurrentUser
  sharifyData: sharify.data
{ loginPath, signupPath, twitterCallbackPath, facebookCallbackPath } = artsyPassport.options

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

Now access your Artsy user in a variety of ways...

In your server-side templates

````jade
if user
  h1 Hello #{user.get('name')}
else
  a( '/login' ) Log in
````

In your client-side code

````coffeescript
CurrentUser = require '../models/current_user.coffee'
sd = require('sharify').data

new View user: if sd.CURRENT_USER then new CurrentUser(sd.CURRENT_USER) else null
````

In your routers

````coffeescript
app.get '/', (req, res) ->
  if req.user?
    res.render 'loggedin'
  else
    res.render 'login'
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