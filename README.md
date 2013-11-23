# artsy-passport

Wires up the common auth handlers for Artsy's [Ezel](ezeljs.com)-based apps using [passport](http://passportjs.org/).

## Features

* Authenticates with Facebook and Twitter
* Fetches the current user and caches their JSON data in the session
* Serializes `req.user` into a backbone model populated by the cached user JSON
* Provides endpoints to ajax POST for signup and login
* Bootstraps the current user as `sd.CURRENT_USER` in [sharify](https://github.com/artsy/sharify) data
* Signup routes that create the user and log them in to `req.user`
* Redirects to / after Twitter/Facebook login

## Example

Mount middlware passing a big configuration hash like so below. The values indicated defaults.

````coffeescript
app.use artsyAuth
  facebookID: # Facebook app ID
  facebookSecret: # Facebook app secret
  twitterKey: # Twitter consumer key
  twitterSecret: # Twitter consumer secret
  callbackUrl: # Url pointing back to your app e.g. http://flare.artsy.net
  artsyID: # Artsy client id
  artsySecret: # Artsy client secret
  artsySecureUrl: 'http://artsy.net' # SSL Artsy url
  facebookPath: '/users/auth/facebook' # Url to point your facebook button to
  twitterPath: '/users/auth/twitter' # Url to point your twitter button to
  loginPath: '/users/sign_in' # POST `email` and `password` to login via ajax
  signupPath: '/users/invitation/accept' # POST `email` and `password` to signup via ajax
  twitterCallback: '/auth/twitter/callback' # After twitter auth callback url
  facebookCallback: '/auth/facebook/callback' # After facebook auth callback url
````