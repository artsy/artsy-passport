_ = require 'underscore'
Browser = require 'zombie'
app = require '../example'
artsyXapp = require 'artsy-xapp'
{ ARTSY_EMAIL, ARTSY_PASSWORD, TWITTER_EMAIL, TWITTER_PASSWORD,
  FACEBOOK_EMAIL, FACEBOOK_PASSWORD, ARTSY_URL, ARTSY_ID,
  ARTSY_SECRET } = require '../config'

describe 'Artsy Passport', ->

  before (done) ->
    artsyXapp.on('error', done).init
      url: ARTSY_URL
      id: ARTSY_ID
      secret: ARTSY_SECRET
    , -> app.listen 5000, done

  it 'can sign up with email and password', (done) ->
    Browser.visit 'http://localhost:5000', (e, browser) ->
      browser
        .fill('#signup [name="name"]', 'Foobar')
        .fill('#signup [name="email"]', "ap+#{_.random(0, 1000)}@artsypassport.com")
        .fill('#signup [name="password"]', 'moofooboo')
        .pressButton "Signup", ->
          browser.html().should.containEql 'Personalize!'
          done()

  it 'can log in and log out with email and password', (done) ->
    Browser.visit 'http://localhost:5000', (e, browser) ->
      browser
        .fill('#login [name=email]', ARTSY_EMAIL)
        .fill('#login [name=password]', ARTSY_PASSWORD)
        .pressButton "#login [type=submit]", ->
          browser.html().should.containEql '<h1>Hello'
          browser.html().should.containEql ARTSY_EMAIL
          browser
            .clickLink "Logout", ->
              browser.reload ->
                browser.html().should.containEql '<h1>Login'
                done()

  it 'cant log in without a csrf', (done) ->
    Browser.visit 'http://localhost:5000/nocsrf', (e, browser) ->
      browser
        .fill('#login [name=email]', ARTSY_EMAIL)
        .fill('#login [name=password]', ARTSY_PASSWORD)
        .pressButton "#login [type=submit]", ->
          browser.html().should.containEql 'ForbiddenError: invalid csrf token'
          done()

  it 'can log in with facebook', (done) ->
    Browser.visit 'http://localhost:5000', (e, browser) ->
      browser.clickLink "Login via Facebook", ->
        browser.location.href.should.containEql 'facebook.com'
        browser
          .fill('email', FACEBOOK_EMAIL)
          .fill('pass', FACEBOOK_PASSWORD)
          .pressButton 'Log In', ->
            console.log browser.html()
            done()

  it 'can log in with twitter', (done) ->
    Browser.visit 'http://localhost:5000', (e, browser) ->
      browser.clickLink "Login via Twitter", ->
        browser.location.href.should.containEql 'twitter.com'
        browser
          .fill('session[username_or_email]', TWITTER_EMAIL)
          .fill('session[password]', TWITTER_PASSWORD)
          .pressButton 'Authorize app', ->
            console.log browser.html()
            done()
