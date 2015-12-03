sd = require('sharify').data

$ ->
  if sd.CURRENT_USER
    $('body').append "<br><br>your email from the client-side!<br> " + sd.CURRENT_USER.email
    $('[href*=sign_out]').click (e) ->
      e.preventDefault()
      $.ajax
        url: '/users/sign_out'
        type: 'DELETE'
        success: ->
          window.location = '/'
        error: (xhr, status, error) ->
          alert(error)
    $('[href*=delete]').click (e) ->
      e.preventDefault() unless confirm "Are you sure?"
  else
    $('#trust button').click ->
      $.ajax
        type: 'POST'
        url: "#{sd.ARTSY_URL}/api/v1/me/trust_token"
        headers: 'x-access-token': $('#trust input').val().trim()
        error: (e) ->
          alert 'Error!'
          console.warn e
        success: ({ trust_token }) ->
          window.location = "http://#{location.host}?trust_token=#{trust_token}"
