describe '#logout', ->

  it 'logs out, deletes the auth token, and redirects home'

describe '#denyBadLogoutLinks', ->

  it 'ensures the referrer is artsy to avoid the img src= logout hack', ->
