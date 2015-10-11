@Units = new Mongo.Collection 'units',
  transform: (data) ->
    new Unit data

UnitSchema = new SimpleSchema
  roundId:
    type: String
  x:
    type: Number
  y:
    type: Number
  angle:
    type: Number
    min: 0
    max: 360
  name:
    type: String
  type:
    type: String
  image:
    type: String
  health:
    type: Number
  minShootingrange:
    type: Number
  maxShootingrange:
    type: Number
  moverange:
    type: Number
  damage:
    type: Object
    blackbox: true
  moved:
    type: Boolean
    optional: true
  attacked:
    type: Boolean
    optional: true

# Units.attachSchema UnitSchema

class Unit extends Model

  @_collection: Units

  getMaxHealth: ->
    @maxHealth or 100

  getHealth: ->
    @health ?= 100

  getMaxStrength: ->
    # TODO: get this from the unit type
    @maxStrength or 10

  atMaxStrength: ->
    @getMaxStrength() is @getStrength()

  getDamage: (unit) ->
    return 0 if not dmg = @damage?[unit.type]

    Math.ceil @getStrengthDamageModifier() * (dmg + (0.8 + Math.random() * 0.4))

  getStrength: ->
    health = @getHealth()

    if not health
      0
    else
      Math.ceil (health / @getMaxHealth()) * @getMaxStrength()

  getStrengthDamageModifier: ->
    (@getStrength() / @getMaxStrength())

  getTeamColor: ->
    @findPlayer().getTeamColor()

  findRound: ->
    Rounds.findOne @roundId

  findPlayer: ->
    Players.findOne @playerId

  ownedByCurrentPlayer: ->
    @playerId is @findRound().getCurrentPlayer()._id

  findUnitType: (optons) ->
    UnitTypes.findOne @unitTypeId, options

  findTargets: ->
    return if @hasAttacked

    Units.find
      _id: $ne: @_id
      playerId: $ne: @playerId
      $or: [
        y: @y
        $and: [
          x: $lte: @x + 1
        ,
          x: $gte: @x - 1
        ]
      ,
        x: @x
        $and: [
          y: $lte: @y + 1
        ,
          y: $gte: @y - 1
        ]
      ]

  canTarget: (unit = {}) ->
    return false if not @canAttack()
    return false if unit.playerId is @playerId
    return false if not @getDamage unit

    (unit.x is @x and unit.y >= @y-1 and unit.y <= @y+1) or
    (unit.y is @y and unit.x >= @x-1 and unit.x <= @x+1)

  canMove: ->
    not @moved and not @hasAttacked and @canDoAction()

  canAttack: ->
    not @attacked and @canDoAction()

  getAngleToPoint: (point) ->
    90 + Math.atan2(point.y - @y, point.x - @x) * 180 / Math.PI;

  attack: (unit = {}) ->
    return unless @canTarget unit

    @set
      attacked: true
      angle: @getAngleToPoint unit

    unit.set
      angle: unit.getAngleToPoint this

    unit.takeDamage @getDamage(unit)

    @takeDamage unit.getDamage this

  takeDamage: (damage) ->
    health = Math.max(0, @getHealth() - damage)

    if health is 0
      @remove()
    else
      @set health: health

  canDoAction: ->
    player = @findPlayer()

    return false unless player.isCurrentPlayer()

    (not Meteor.isClient) or player.userId is Meteor.userId()

  moveAlongPath: (path) ->
    return unless @canMove()
    return unless path.length > 1

    unit = this

    createWaitPromite = (i) ->
      point = path[i]

      if not point
        new Promise (resolve, reject) -> resolve()
      else
        new Promise (resolve, reject) ->
          timeout = if i is 0 then 0 else 200

          update =
            x: point[0]
            y: point[1]

          if previousPoint = path[i-1]
            if previousPoint[0] > point[0]
              update.angle = -90
            else if previousPoint[0] < point[0]
              update.angle = 90
            else if previousPoint[1] > point[1]
              update.angle = 0
            else if previousPoint[1] < point[1]
              update.angle = 180

          Meteor.setTimeout ->
            unit.set update

            createWaitPromite(i+1).then resolve
          , timeout

    createWaitPromite(0).then =>
      @set moved: true
