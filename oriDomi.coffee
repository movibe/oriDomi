###
* oriDomi
* fold up the DOM
*
* Dan Motzenbecker
* (c) 2012
###


root = window
$ = root.$ or false
silent = false
testEl = document.createElement 'div'
prefixList = ['webkit', 'Moz', 'O', 'ms', 'Khtml']
transitionEnd = 'webkitTransitionEnd transitionend oTransitionEnd MSTransitionEnd KhtmlTransitionEnd'
oriDomiSupport = true


testProp = (prop) ->
  return prop if testEl.style[prop]?
  capProp = prop.charAt(0).toUpperCase() + prop.slice 1
  for prefix in prefixList
    if testEl.style[prefix + capProp]?
      return prefix + capProp
  false

# one dimensional:
extendObj = (target, source) ->
  if source isnt Object source
    !silent and console?.warn 'oriDomi: Must pass an object to extend with'
    return target
  if target isnt Object target
    target = {}
  for prop of source
    if not target[prop]?
      target[prop] = source[prop]

  target


transformProp = testProp 'transform'
transformOriginProp = testProp 'transformOrigin'
transformStyleProp = testProp 'transformStyle'
transitionProp = testProp 'transition'
perspectiveProp = testProp 'perspective'
backfaceProp = testProp 'backfaceVisibility'
gradientProp = testProp 'linearGradient'

if !transformProp or !transitionProp or !perspectiveProp or 
  !backfaceProp or !transformOriginProp or !transformStyleProp
    oriDomiSupport = false
    console?.warn 'oriDomi: Browser does not support CSS 3D tranforms, disabling'


defaults =
  vPanels: 6
  hPanels: 2
  perspective: 1000
  shading: true
  speed: .6
  oriDomiClass: 'oriDomi'
  silent: false
  smoothStart: true
  shadingIntensity: 1
  easingMethod: ''
  newClass: null


class root.OriDomi

  constructor: (@el, @settings = {}) ->
    if !(@ instanceof OriDomi)
      return new oriDomi @el, @settings
    
    silent = true if @settings.silent
    
    if !@el? or @el.nodeType isnt 1
      return !silent and console?.warn 'oriDomi: First argument must be a DOM element'
    
    {@shading, @shadingIntensity, @vPanels, @hPanels} = @settings
    @$el = $ @el if $
    elStyle = root.getComputedStyle @el

    @width = parseInt(elStyle.width, 10) +
             parseInt(elStyle.paddingLeft, 10) +
             parseInt(elStyle.paddingRight, 10)

    @height = parseInt(elStyle.height, 10) +
              parseInt(elStyle.paddingTop, 10) +
              parseInt(elStyle.paddingBottom, 10)


    @panelWidth = Math.floor(@width / @vPanels) or 1
    @panelHeight = Math.floor(@height / @hPanels) or 1
    
    @axes = ['left', 'right', 'top', 'bottom']
    @lastAnchor = @axes[0]
    @panels = {}
    @stages = {}
    stage = document.createElement 'div'
    stage.style.display = 'none'
    stage.style.width = @width + 'px'
    stage.style.height = @height + 'px'
    stage.style.position = 'absolute'
    stage.style.padding = '0'
    stage.style.margin = '0'


    for axis in @axes
      @panels[axis] = []
      @stages[axis] = stage.cloneNode()
      @stages[axis].className = 'oridomi-stage-' + axis

    if @shading
      @shaders = {}
      for axis in @axes
        @shaders[axis] = {}
        if axis is 'left' or axis is 'right'
          @shaders[axis].left = []
          @shaders[axis].right = []
        else
          @shaders[axis].top = []
          @shaders[axis].bottom = []

      shader = document.createElement 'div'
      shader.style[transitionProp] = "opacity #{@settings.speed}s"
      shader.style.position = 'absolute'
      shader.style.width = '100%'
      shader.style.height = '100%'
      shader.style.opacity = '0'
      shader.style.top = '0'
      shader.style.left = '0'

    contentHolder = @el.cloneNode true
    contentHolder.classList.add 'oridomi-content'
    contentHolder.margin = '0'

    hMask = document.createElement 'div'
    hMask.className = 'oridomi-mask-h'
    hMask.style.position = 'absolute'
    hMask.style.overflow = 'hidden'
    hMask.style.height = @panelHeight + 'px'
    hMask.appendChild contentHolder

    if @shading
      topShader = shader.cloneNode()
      topShader.className = 'oridomi-shader-top'
      topShader.style.background = '-webkit-linear-gradient(top, rgba(0, 0, 0, .5) 0%, rgba(255, 255, 255, .35) 100%)'
      bottomShader = shader.cloneNode()
      bottomShader.className = 'oridomi-shader-bottom'
      bottomShader.style.background = '-webkit-linear-gradient(bottom, rgba(0, 0, 0, .5) 0%, rgba(255, 255, 255, .35) 100%)'
      hMask.appendChild topShader
      hMask.appendChild bottomShader

    hPanel = document.createElement 'div'
    hPanel.className = 'oridomi-panel-h'
    hPanel.style.width = '100%'
    hPanel.style.height = @panelHeight + 'px'
    hPanel.style.padding = '0'
    hPanel.style[transformProp] = @_transform [0, @panelHeight]
    hPanel.style[transitionProp] = "all #{@settings.speed}s #{@settings.easingMethod}"
    #hPanel.style[transformOriginProp] = '0'
    hPanel.style[transformStyleProp] = 'preserve-3d'
    hPanel.style[backfaceProp] = 'hidden'
    hPanel.appendChild hMask


    for anchor in ['top', 'bottom']
      for i in [1..@hPanels]
        panel = hPanel.cloneNode true
        content = panel.getElementsByClassName('oridomi-content')[0]

        if anchor is 'top'
          y = (i - 1) * @panelHeight * -1
          if i is 1
            panel.style[transformProp] = @_transform [0, 0]
        else
          y = ((@hPanels * @panelHeight) - (@panelHeight * i)) * -1
          if i is 1
            panel.style[transformProp] = @_transform [0, @panelHeight * (@hPanels - 1)]
          else
            panel.style[transformProp] = @_transform [0, -@panelHeight]
          
        content.style[transformProp] = @_transform [0, y]

        if @shading
          @shaders[anchor][i - 1] = panel.getElementsByClassName('oridomi-shader-top')[0]
          @shaders[anchor][i - 1] = panel.getElementsByClassName('oridomi-shader-bottom')[0]

        @panels[anchor][i - 1] = panel

        unless i is 1
          @panels[anchor][i - 2].appendChild panel

      @stages[anchor].appendChild @panels[anchor][0]


    vMask = hMask.cloneNode true
    vMask.className = 'oridomi-mask-v'
    vMask.style.width = @panelWidth + 'px'
    vMask.style.height = '100%'

    if @shading
      leftShader = shader.cloneNode()
      leftShader.className = 'oridomi-shader-left'
      rightShader = shader.cloneNode()
      rightShader.className = 'oridomi-shader-right'
      vMask.appendChild leftShader
      vMask.appendChild rightShader

    vPanel = hPanel.cloneNode()
    vPanel.className = 'oridomi-panel-v'
    vPanel.style.width = @panelWidth + 'px'
    vPanel.style.height = '100%'
    vPanel.style[transformProp] = @_transform [@panelWidth, 0]
    vPanel.appendChild vMask

    for anchor in ['left', 'right']
      for i in [1..@vPanels]
        panel = vPanel.cloneNode true
        content = panel.getElementsByClassName('oridomi-content')[0]

        if anchor is 'left'
          x = (i - 1) * @panelWidth * -1
          if i is 1
            panel.style[transformProp] = @_transform [0, 0]
        else
          x = ((@vPanels * @panelWidth) - (@panelWidth * i)) * -1
          if i is 1
            panel.style[transformProp] = @_transform [@panelWidth * (@vPanels - 1), 0]
          else
            panel.style[transformProp] = @_transform [-@panelWidth, 0]


        content.style[transformProp] = @_transform [x, 0]

        if @shading
          @shaders[anchor][i - 1] = panel.getElementsByClassName('oridomi-shader-left')[0]
          @shaders[anchor][i - 1] = panel.getElementsByClassName('oridomi-shader-right')[0]

        @panels[anchor][i - 1] = panel

        unless i is 1
          @panels[anchor][i - 2].appendChild panel

      @stages[anchor].appendChild @panels[anchor][0]


    @el.classList.add @settings.oriDomiClass
    @el.style.padding = '0'
    @el.style.width = @width + 'px'
    @el.style.height = @height + 'px'
    @el.style.backgroundColor = 'transparent'
    #@el.style[transitionProp] = "all #{@settings.speed}s #{@settings.easingMethod}"
    @el.style[perspectiveProp] = @settings.perspective
    @stages.left.style.display = 'block'
    @el.innerHTML = ''

    for axis in @axes
      @el.appendChild @stages[axis]

    @_callback @settings


  _callback: (options) ->
    if typeof options.callback is 'function'
      @panels[0].addEventListener transitionEnd, =>
        @panels[0].removeEventListener transitionEnd, true
        options.callback()
      , true


  _transform: (translation, rotation) ->
    [x, y] = translation
    if !rotation
      "translate3d(#{ x }px, #{ y }px, 0)"
    else
      [rX, rY, rZ, deg] = rotation
      "translate3d(#{ x }px, #{ y }px, 0) rotate3d(#{ rX }, #{ rY }, #{ rZ }, #{ deg }deg)"


  _normalizeAngle: (percent) ->
    percent = parseFloat percent, 10
    if isNaN percent
      0
    else if percent > 90
      !silent and console?.warn 'oriDomi: Maximum value is 90'
      90
    else if percent < -90
      !silent and console?.warn 'oriDomi: Minimum value is -90'
      -90
    else
      percent


  _accordionDefaults:
    anchor: true
    stairs: false
    fracture: false
    twist: false


  _resetRow: (column) ->
    for panel, i in @hPanels[column]
      if i is 0
        panel.style[transformProp] = 'translate3d(0, 0, 0)'
      else
        panel.style[transformProp] = 'translate3d(0, #{@panelHeight}px, 0)'


  accordion: (angle, axis = 'h', options) ->
    options = extendObj options, @_accordionDefaults
    angle = @_normalizeAngle angle
    left = @panelWidth - 1

    for panel, i in @vPanels

      if axis is 'h'
  
        @_resetRow i
        
        if i % 2 isnt 0 and !options.twist
          deg = -angle
        else
          deg = angle
  
        x = left
        ++x if angle is 90
  
        if options.anchor
          if i is 0
            x = 0
            deg = 0
          else if i > 1 or options.stairs
            deg *= 2
        else
          if i is 0
            x = 0
          else
            deg *= 2
  
        if options.fracture
          rotation = "rotate3d(1, 1, 1, #{deg}deg)"
        else
          rotation = "rotate3d(0, 1, 0, #{deg}deg)"
      
      else
        deg = 0

        if i is 0
          x = 0
        else
          x = @panelWidth
        
        for hPanel, j in @hPanels[i]
          
          if j % 2 isnt 0 and !options.twist
            yDeg = -angle
          else
            yDeg = angle
          
          if j is 0
            y = 0
            yDeg = 0
          else
            y = @panelHeight
            yDeg
          


      panel.style[transformProp] = "translate3d(#{x}px, 0, 0) #{rotation}"

      if @settings.shading and !(i is 0 and options.anchor)
        if axis isnt 'h'
          opacity = 0
        else
          opacity = Math.abs(angle) / 90 * @settings.shadingIntensity * .4
        
        if deg < 0
          @rightShaders[i].style.opacity = 0
          @leftShaders[i].style.opacity = opacity
        else
          @leftShaders[i].style.opacity = 0
          @rightShaders[i].style.opacity = opacity

    @_callback options


  reset: ->
    @accordion 0


  collapse: (axis) ->
    @accordion -90, axis, anchor: false


  collapseAlt: ->
    @accordion 90, axis, anchor: false


  reveal: (angle, axis, options = {}) ->
    options.anchor = true
    @accordion angle, axis, options


  stairs: (angle, axis, options = {}) ->
    options.stairs = true
    options.anchor = true
    @accordion angle, axis, options


  fracture: (angle, axis, options = {}) ->
    options.fracture = true
    @accordion angle, axis, options


  twist: (angle, axis, options = {}) ->
    options.fracture = true
    options.twist = true
    @accordion angle / 10, axis, options


  curl: (angle, axis, options = {}) ->
    angle = @_normalizeAngle(angle) / @panelWidth * 10

    for panel, i in @panels
      x = if i is 0 then 0 else @panelWidth - 1
      panel.style[transformProp] = "translate3d(#{x}px, 0, 0) rotate3d(0, 1, 0, #{angle}deg)"

    @_callback options


  setAngles: (angles, axis, options = {}) ->
    if !Array.isArray angles
      return !silent and console?.warn 'oriDomi: Argument must be an array of angles'
    
    for panel, i in @panels
      x = if i is 0 then 0 else @panelWidth - 1
      angle = @_normalizeAngle(angles[i])
      
      unless i is 0
        angle *= 2
      
      panel.style[transformProp] = "translate3d(#{x}px, 0, 0) rotate3d(0, 1, 0, #{angle}deg)"
      
    @_callback options


# $ BRIDGE

if $
  $.fn.oriDomi = (options) ->
    return @ if !oriDomiSupport

    if typeof options is 'string'

      if typeof OriDomi::[options] isnt 'function'
        return !silent and console?.warn "oriDomi: No such method '#{options}'"

      for el in @
        instance = $.data el, 'oriDomi'

        if not instance?
          return !silent and console?.warn "oriDomi: Can't call #{options}, oriDomi hasn't been initialized on this element"

        args = Array::slice.call arguments
        args.shift()
        instance[options].apply instance, args

      @

    else
      settings = extendObj options, defaults

      for el in @
        instance = $.data el, 'oriDomi'
        if instance
          return instance
        else
          $.data el, 'oriDomi', new OriDomi el, settings

      @

