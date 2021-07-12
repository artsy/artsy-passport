const _ = require('underscore');
const Browser = require('zombie');
const app = require('../example');
const artsyXapp = require('@artsy/xapp');
const { ARTSY_EMAIL, ARTSY_PASSWORD, FACEBOOK_EMAIL, FACEBOOK_PASSWORD,
  ARTSY_URL, ARTSY_ID, ARTSY_SECRET } = require('../config');

describe('Artsy Passport', function() {
  before(function(done) {
    artsyXapp.on('error', done).init({
      url: ARTSY_URL,
      id: ARTSY_ID,
      secret: ARTSY_SECRET
    }, () => {
      app.listen(5000, () => {
        done()
      });
    })
  });

  it('can sign up with email and password', function(done) {
    Browser.visit('http://localhost:5000', (e, browser) => browser
      .fill('#signup [name="name"]', 'Foobar')
      .fill('#signup [name="email"]', `ap+${_.random(0, 1000)}@artsypassport.com`)
      .fill('#signup [name="password"]', 'moofooboo')
      .pressButton("Signup", function() {
        browser.html().should.containEql('Personalize!');
        done();
    }))
  });

  it('can log in and log out with email and password', function(done) {
    Browser.visit('http://localhost:5000', (e, browser) => browser
      .fill('#login [name=email]', ARTSY_EMAIL)
      .fill('#login [name=password]', ARTSY_PASSWORD)
      .pressButton("#login [type=submit]", function() {
        browser.html().should.containEql('<h1>Hello');
        browser.html().should.containEql(ARTSY_EMAIL);
        browser
          .clickLink("Logout", () => browser.reload(function() {
          browser.html().should.containEql('<h1>Login');
          done();
        }));
    }))
  });

  it('cant log in without a csrf', function(done) {
    Browser.visit('http://localhost:5000/nocsrf', (e, browser) => browser
      .fill('#login [name=email]', ARTSY_EMAIL)
      .fill('#login [name=password]', ARTSY_PASSWORD)
      .pressButton("#login [type=submit]", function() {
        browser.html().should.containEql('ForbiddenError: invalid csrf token');
        done();
    }))
  });

  it('can log in with facebook', function(done) {
    Browser.visit('http://localhost:5000', (e, browser) => browser.clickLink("Login via Facebook", function() {
      browser.location.href.should.containEql('facebook.com');
      browser
        .fill('email', FACEBOOK_EMAIL)
        .fill('pass', FACEBOOK_PASSWORD)
        .pressButton('Log In', function() {
          console.log(browser.html());
          done();
      });
    }))
  });
});
