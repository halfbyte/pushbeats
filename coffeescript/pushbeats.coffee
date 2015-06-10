window.PB = {}

class PB.MasterControl extends Backbone.View
  el: '.master-controls'
  events:
    'click #play': "togglePlay"
    'change #tempo': "changeTempo"

  initialize: ->
    @model.on 'tempo-changed', (tempo) =>
      @$('#tempo').val(tempo)
    @model.on 'playing', =>
      @$('#play').html('Stop').addClass('playing')
    @model.on 'stopped', =>
      @$('#play').html('Play').removeClass('playing')

  togglePlay: (e) =>
    console.log(@model)
    e.preventDefault()
    @model.trigger('start-stop')

  changeTempo: (e) =>
    console.log("change Tempo", e.target.value)
    @model.trigger('change-tempo', e.target.value)

class PB.GridControl extends Backbone.View
  el: '#grid'
  events:
    'click .grid-box': 'toggleGridBox'

  initialize: ->
    console.log("Init Grid", @$el)
    @model.on 'grid-set', (row, col) =>
      @$("#grid-#{row}-#{col}").addClass('set')
    @model.on 'grid-clear', (row, col) =>
      @$("#grid-#{row}-#{col}").removeClass('set')

  toggleGridBox: (e) =>
    match = e.target.id.match(/grid-(\d+)-(\d+)/)
    row = match[1]
    col = match[2]

    e.preventDefault()
    @model.trigger('toggle-grid', row, col)





class PB.Sequencer
  constructor: ->
    _.extend this, Backbone.Events
    @tempo = 120
    @play = false
    console.log(this)

    @grid = [
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    ]

    @on 'inc-tempo', (inc) =>
      console.log("inc-tempo", inc)
      @tempo += inc
      @tempo = 200 if @tempo > 200
      @trigger('tempo-changed', @tempo)
    @on 'dec-tempo', (inc) =>
      console.log("dec-tempo", inc)
      @tempo -= inc
      @tempo = 50 if @tempo < 50
      @trigger('tempo-changed', @tempo)



    @on 'change-tempo', (tempo) =>
      @tempo = tempo
      @trigger('tempo-changed', tempo)
    @on 'start-stop', =>
      @play = not @play
      if @play
        @trigger('playing')
      else
        @trigger('stopped')

    @on 'toggle-grid', (row, col) =>
      @grid[row - 1][col - 1] = not @grid[row - 1][col - 1]
      if @grid[row - 1][col - 1]
        @trigger('grid-set', row, col)
      else
        @trigger('grid-clear', row, col)
      console.log(@grid)


class PB.Sound
  constructor: (@params)->
    console.log(@params)
    _.extend(this, Backbone.Events)
    @on 'value-change', (name, value) =>
      console.log(@params, name)
      @params[name].value = value
      @trigger('value-changed', name, value)
      console.log("value changed", name, value)
    @on 'value-inc', (name, inc) =>
      @params[name].value += inc
      @params[name].value = @params[name].max if @params[name].value > @params[name].max
      @trigger('value-changed', name, value)
    @on 'value-dec', (name, inc) =>
      @params[name].value += inc
      @params[name].value = @params[name].max if @params[name].value > @params[name].max
      @trigger('value-changed', name, value)




class PB.BaseDrum extends PB.Sound
  params:
    sweep:
      min: 0
      max: 127
      name: 'Sweep'
      value: 64
    decay:
      min: 0
      max: 127
      name: 'Decay'
      value: 64


class PB.SoundView extends Backbone.View
  events:
    "change input": "valueChanged"

  valueChanged: (e) =>
    console.log(e.target)
    name = e.target.name
    @model.trigger('value-change', name, e.target.value)

  initialize: =>
    @model.on 'value-changed', (name, value) =>
      @$("##{name}").val(value)


class PB.PushInterface extends Backbone.View
  initialize: ->
    @SLOTS = [0,9,17,26, 34,43,51,60]

    console.log("INIT MIDI")
    navigator.requestMIDIAccess(sysex: true).then(@initMIDI, @failMIDI);


  initMIDI: (info) =>
    info.inputs.forEach (input) =>
      console.log(input.name)
      if input.name == 'Ableton Push User Port'
        @input = input
        input.onmidimessage = @onMIDIMessage

    info.outputs.forEach (output) =>
      console.log(output.name)
      if output.name == 'Ableton Push User Port'
        @userOutput = output

      if output.name == 'Ableton Push Live Port'
        @liveOutput = output

    @postInit()

  failMIDI: (message) =>
    alert(message)

  onMIDIMessage: (message) =>
    data = message.data

    if data[0] == 144
      if data[1] >= 36 and data[1] <= 99
        # we have a grid
        note = data[1] - 36
        y = (7 - Math.floor(note / 8))
        x = (note % 8)
        [row, col] = @xy2ColRow(x,y)
        @model.trigger('toggle-grid', row, col)
        return
    if data[0] == 176
      if data[1] == 14
        if (data[2] < 64)
          @model.trigger('inc-tempo', data[2])
          return
        else
          @model.trigger('dec-tempo', 128-data[2])
          return
      if data[1] == 85
        if data[2] == 127
          @model.trigger('start-stop')

    console.log("IN", data)


  send: (bytes) =>
    @userOutput.send(bytes)

  sendSysEx: (bytes) =>
    @liveOutput.send(bytes)

  setPad: (x,y, note) ->
    pad = 36 + ((7 - y) * 8) + x
    @send [144,pad, note]

  xy2ColRow: (x,y) ->
    row = Math.floor(y / 2) + 1
    col = x + 1
    col = col + 8 if y % 2 == 1
    [row, col]

  rowCol2XY: (row, col) ->
      y = (row - 1) * 2
      x = col - 1
      y += 1 if col > 8
      x = x % 8
      [x,y]

  strToBytes: (instring) ->
    bytes = []
    for i in [0...instring.length]
      charcode = instring.charCodeAt(i)
      if charcode < 127
        bytes.push(charcode)
    bytes

  textInSlot: (line, slot, str) ->
    offset = @SLOTS[slot]
    if str.length > 8
      str = str.slice(0,8)
    str = str + "        ".substr(0, 8 - str.length)
    @sendSysEx @displaySysEx(line, offset, @strToBytes(str))

  valueInSlot: (line, slot, val) ->
    offset = @SLOTS[slot]
    str = val.toString(10)
    str = "        ".substr(0, 8 - str.length) + str
    @sendSysEx @displaySysEx(line, offset, @strToBytes(str))

  displaySysEx: (line, offset, strBytes) ->
    maxLen = 68 - offset

    if strBytes.length > maxLen
      strBytes = strBytes.slice(0,maxLen)
    message = [240, 71, 127, 21, line + 24, 0, strBytes.length + 1, offset]
    message = message.concat(strBytes);
    message.push(247);
    message

  postInit: =>

    for note in [36..99]
      @send([128,note, 0])

    @model.on "grid-set", (row, col) =>
      console.log("SET")
      [x, y] = @rowCol2XY(row, col)
      @setPad(x,y, 10 )
    @model.on "grid-clear", (row, col) =>
      console.log("CLEAR")
      [x, y] = @rowCol2XY(row, col)
      @setPad(x,y, 0)

    @model.on "playing", =>
      @send([176, 85, 4])
    @model.on "stopped", =>
      @send([176, 85, 1])

    @send([176, 85, 1])
    @textInSlot(3, 0, "BaseDrum")
    @textInSlot(3, 1, "SnreDrum")
    @textInSlot(3, 2, "HHatClos")
    @textInSlot(3, 3, "HHatOpen")



basedrum = new PB.Sound
  sweep:
    min: 0
    max: 127
    name: 'Sweep'
    value: 64
  decay:
    min: 0
    max: 127
    name: 'Decay'
    value: 64
  start:
    min: 0
    max: 127
    name: 'Decay'
    value: 64
  end:
    min: 0
    max: 127
    name: 'Decay'
    value: 64

snaredrum = new PB.Sound
  sweep:
    min: 0
    max: 127
    name: 'Sweep'
    value: 64
  decay:
    min: 0
    max: 127
    name: 'Decay'
    value: 64
  start:
    min: 0
    max: 127
    name: 'Decay'
    value: 64
  end:
    min: 0
    max: 127
    name: 'Decay'
    value: 64
  lowpass:
    min: 0
    max: 127
    name: 'Frequency'
    value: 64


bdview = new PB.SoundView(model: basedrum, el: '#basedrum')
sdview = new PB.SoundView(model: snaredrum, el: '#snaredrum')

sequencer = new PB.Sequencer()

PB.MC = new PB.MasterControl(model: sequencer)
PB.Grid = new PB.GridControl(model: sequencer)
PB.Push = new PB.PushInterface(model: sequencer)




console.log("UHU")
