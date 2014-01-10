loadTimeline = ->
  console.log "Looking up timeline"
  $.get( "/timeline.json" ).done( (data)->
    console.log data

    $("#timeline_status").html( data.status )
    if data.status == 'loaded'
      $("#timeline").html ""
      for tweet in data.data
        $("#timeline").append( "<li><span class='date'>"+tweet.created_at+"</span>:<span class='tweet'>" + tweet.text + "</span></li>")
    else
      console.log "Waiting"
      setTimeout loadTimeline, 2000
  )

loadFriends = ->
  console.log "Looking up friends"
  $.get( "/friends.json" ).done( (data)->
    console.log data

    $("#friends_status").html( data.status )
    if data.status == 'loaded'
      $("#friends").html ""
      for tweet in data.data
        $("#friends").append( "<li><span class='user'>"+tweet+"</span>" )
    else
      console.log "Waiting"
      setTimeout loadFriends, 2000
  )

$ ->
  loadTimeline()
  loadFriends()