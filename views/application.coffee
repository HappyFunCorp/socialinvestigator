app = angular.module( "socialinvestigator", ['ngRoute'] )


app.config ['$routeProvider', ($routeProvider) ->
  $routeProvider.
    when( '/user/:user', { templateUrl: '/user.html', controller: "UserController" } ).
    when( '/home', { templateUrl: '/home.html', controller: "HomeController" } ).
    otherwise({ redirectTo: '/home' })
]

app.run( ["$rootScope", ($rootScope) ->
  $rootScope.logged_in = window.logged_in
  $rootScope.words = [["This",20],["That",15],["Other",10],["test",1]]
] )

class DataLoader
  constructor: (@endpoint, @http, @timeout, @location) ->
    console.log "Creating dataloader:" + @endpoint
    # @scope.$watch "user", -> @load()
    @data = []
    @delay = 1000

  scope: (@s) ->
    @s.status = "Loading..."
    @s.data = []
    @s.$watch "user", (newData) => 
      @delay = 1000
      @load(newData)
    @load(@s.user)

  load: (user)->
    if @poll
      console.log "Killing old poll"
      @timeout.cancel @poll
    console.log "Calling load: " + user
    params = {}
    params.screen_name = user if user
    @http.get( @endpoint, {params: params } ).success (data) =>
      @s.status = data.status
      # console.log data.data
      @s.data = data.data
      # console.log @endpoint+":"+data.status
      if data.status != "loaded" && data.status != "not_logged_in"
        @poll = @timeout(
          =>
            @poll = null 
            @load(user)
          ,
          @delay
          )
        @delay *= 2
      else
        @delay = 1000

app.service 'Timeline', [ '$http', '$timeout', '$location', ($http, $timeout, $location) ->
  new DataLoader( '/timeline.json', $http, $timeout, $location )
]

app.service 'Wordcloud', [ '$http', '$timeout', '$location', ($http, $timeout, $location) ->
  new DataLoader( '/wordcloud.json', $http, $timeout, $location )
]

app.service 'UserInfo', [ '$http', '$timeout', '$location', ($http, $timeout, $location) ->
  new DataLoader( '/userinfo.json', $http, $timeout, $location )
]

app.service 'Friends', [ '$http', '$timeout', '$location', ($http, $timeout, $location) ->
  new DataLoader( '/friends.json', $http, $timeout, $location )
]

@DashboardController = ["$scope", "$http", "$location", "$rootScope", ($scope, $http, $location, $rootScope) ->
  $scope.whoami = "Anonymous"

  $http.get( "/whoami.json" ).success (data) =>
    $scope.whoami = data.screen_name
    if $scope.whoami
      $location.path( "/user/" + $scope.whoami ) 
      $rootScope.logged_in = true

  $scope.show_user = (user) ->
    $location.path( "/user/" + user )
]

@HomeController = ["$scope","$location",($scope, $location) ->
  console.log "Home Controller"

  if $scope.logged_in
    $location.path( "/user/" + $scope.whoami ) 

]

@UserController = ["$scope","$routeParams", ($scope,$routeParams) ->
  console.log "User is:"+$routeParams.user
  $scope.user = $routeParams.user
]

@TimelineController = ["$scope", "Timeline", ($scope, Timeline) ->
  Timeline.scope( $scope )
]

@WordcloudController = ["$scope", "Wordcloud", ($scope, Wordcloud) ->
  $scope.data = [["test", 10],["test2",5]]
  Wordcloud.scope( $scope )
]

@FriendsController = ["$scope", "Friends", ($scope, Friends) ->
  Friends.scope( $scope )
]

@UserInfoController  = ["$scope", "UserInfo", ($scope, UserInfo) ->
  UserInfo.scope( $scope )
]