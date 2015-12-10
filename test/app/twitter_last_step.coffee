
describe 'twitter last step middleware', ->

  describe '#submit', ->

    it 'creates a user'

    it 'logs in a user from the JSON from the PUT call to update the user'

  describe '#login', ->

    it 'ensures the user is logged in from twitter'

  describe '#ensureEmail', ->

    it 'forces a user with a temporary email to go to the one last step'

  describe '#error', ->

    it 'ignores mailchimp errors bubbled up from Gravity'

    it 'sends a sensible error about an account being taken'

    it 'redirects to the twitter last step page with the error message'
