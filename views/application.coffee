app = angular.module( "socialinvestigator", ['ngRoute','d3'] )

app.directive "wordcloud2", [ ->
  restrict: 'E'
  scope:
    words: '='
    graph: '@'
    categories: '@'
  link: (scope, element, attrs) ->
    height = 400
    width = 800
    vis = d3.select(element[0])

    scope.$watch 'words', (newData,oldData) ->
      return if newData == undefined

      # clear the elements inside of the directive
      vis.selectAll('*').remove();

      console.log "words have been set!"

      draw = (words) ->
        height_translate = height / 2;
        width_translate = width / 2;
        rootElement = element[0];
        d3
          .select(element[0])
          .append('svg')
          .attr('width', width)
          .attr('height', height)
          .append('g')
          .attr('transform', 'translate(' + width_translate + ',' + height_translate + ')')
          .selectAll('text').data(words).enter().append('text')
          .style('font-size', (d) -> d.size + 'px' )
          # .style('font-family', fontFamily)
          # .style('fill', (d,i) -> fill(i) )
          .attr('text-anchor', 'middle')
          .attr('transform', (d) -> 'translate(' + [ d.x, d.y ] + ')rotate(' + d.rotate + ')' )
          .text( (d) -> d.text )

        # vis.append("g").attr("transform", "translate(200,220)")
        # .selectAll("text")
        # .data(newData)
        # .enter().append("text")
        # # .style("font-size", function(d) { return d.size + "px"; })
        # # .style("fill", function(d) { return wordColor(d.size); })
        # # .style("opacity", .75)
        # .attr("text-anchor", "middle")
        # .attr("transform", (d) -> "translate(" + [d.x, d.y] + ")rotate(" + d.rotate + ")" )
        # .text( (d) -> d.text )
    
        # vis
        #   .append("text")
        #   .data(newData)
        #   .style("font-size", 20)
        #   .style("font-weight", 900)
        #   .attr("x", 100)
        #   .attr("y", 20)

      cloud = d3.layout.cloud().size([400, 400])
        .words(newData)
        .text( (d) -> d[1] )
        .rotate( -> ~~(Math.random() * 2) * 5 )
        .fontSize( (d) -> 24 + d[0] )
        .on("end", draw)
        .start();

      console.log cloud
      # console.log scope.graph

      # createChart(newData)

    createChart = (data) =>
      id = 'app-chart-'+Math.random().toString(36).substring(2)
      
      element.attr('id',id)

      categories = scope.categories.split ","
      graph = scope.graph.split ","

      @chart = new HighchartsPlot( id, graph, categories, data, scope.name )

  replace: true
]


app.run( ["$rootScope", ($rootScope) ->
  $rootScope.logged_in = window.logged_in
  $rootScope.words = [[20,"This"],[15,"That"],[10,"Other"]]
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
    if !@s.logged_in
      console.log "Not logged in"
      return
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
