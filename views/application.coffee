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

$ ->
  loadTimeline()