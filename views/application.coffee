app = angular.module( "socialinvestigator", ['ngRoute'] )

app.run( ["$rootScope", ($rootScope) ->
  $rootScope.logged_in = window.logged_in
] )

class DataLoader
  constructor: (@endpoint, @http, @timeout) ->
    console.log "Creating dataloader:" + @endpoint
    # @scope.$watch "user", -> @load()
    @data = []

  scope: (@s) ->
    @s.status = "Loading..."
    @s.data = []
    @s.$watch "user", => @load()
    @load()

  load: ->
    if @poll
      console.log "Killing old poll"
      @timeout.cancel @poll
    console.log "Calling load: " + @s.user
    params = {}
    params.screen_name = @s.user if @s.user
    @http.get( @endpoint, {params: params } ).success (data) =>
      @s.status = data.status
      @s.data = data.data
      console.log @endpoint+":"+data.status
      if data.status != "loaded"
        @poll = @timeout(
          =>
            @poll = null 
            @load()
          ,
          2000
          )

app.service 'Timeline', [ '$http', '$timeout', ($http, $timeout) ->
  new DataLoader( '/timeline.json', $http, $timeout )
]

app.service 'Friends', [ '$http', '$timeout', ($http, $timeout) ->
  new DataLoader( '/friends.json', $http, $timeout )
]

@DashboardController = ["$scope", "$http", "$timeout", ($scope, $http, $timeout) ->
  $scope.user = null
  $scope.show_user = (user) ->
    $scope.user = user
]

@TimelineController = ["$scope", "Timeline", ($scope, Timeline) ->
  Timeline.scope( $scope )
]

@FriendsController = ["$scope", "Friends", ($scope, Friends) ->
  Friends.scope( $scope )
]
