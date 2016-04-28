module Ui.ColorPanel exposing
  (Model, Action, init, update, view, handleMove, handleClick, setValue,
   subscriptions, subscribe) -- where

{-| Color panel component for selecting a colors **hue**, **saturation**,
**value** and **alpha** components with draggable interfaces.

# Model
@docs Model, Action, init, update

# View
@docs view

# Functions
@docs handleMove, handleClick, setValue
-}
import Html.Dimensions exposing (PositionAndDimension)
import Html.Attributes exposing (style, classList)
import Html.Extra exposing (onWithDimensions)
import Html exposing (node, div, text)
-- import Html.Lazy

import Ext.Color exposing (Hsv, decodeHsv, encodeHsv)
import Color exposing (Color)

import Json.Decode as JD

import Ui.Helpers.Emitter as Emitter
import Ui.Helpers.Drag as Drag
import Ui

{-| Representation of a color panel:
  - **readonly** - Whether or not the color panel is editable
  - **disabled** - Whether or not the color panel is disabled
  - **drag** (internal) - The drag model of the value / saturation rectangle
  - **alphaDrag** (internal) - The drag model of the alpha slider
  - **hueDrag** (internal) - The drag model of the hue slider
-}
type alias Model =
  { alphaDrag : Drag.Model
  , hueDrag : Drag.Model
  , drag : Drag.Model
  , disabled : Bool
  , readonly : Bool
  , uid : String
  , value : Hsv
  }

{-| Actions that a color panel can make. -}
type Action
  = LiftAlpha (PositionAndDimension)
  | LiftRect (PositionAndDimension)
  | LiftHue (PositionAndDimension)
  | Move (Int, Int)
  | Click Bool
  | Tasks ()

{-| Initializes a color panel with the given Elm color.

    ColorPanel.init Color.blue
-}
init : Color -> Model
init color =
  { value = Ext.Color.toHsv color
  , alphaDrag = Drag.init
  , hueDrag = Drag.init
  , drag = Drag.init
  , disabled = False
  , readonly = False
  , uid = Native.Uid.uid ()
  }

subscriptions : Sub Action
subscriptions =
  Drag.subscriptions Move Click

{-| Provides a subscription for the changes of a checkbox. -}
subscribe : (Hsv -> a) -> Model -> Sub a
subscribe action model =
  Emitter.listen
    model.uid
    (Emitter.decode decodeHsv (Ext.Color.toHsv Color.black) action)

{-| Updates a color panel. -}
update : Action -> Model -> (Model, Cmd Action)
update action model =
  case action of
    LiftRect {dimensions, position} ->
      { model | drag = Drag.lift dimensions position model.drag }
        |> handleMove (round position.pageX) (round position.pageY)

    LiftAlpha {dimensions, position} ->
      { model | alphaDrag = Drag.lift dimensions position model.alphaDrag }
        |> handleMove (round position.pageX) (round position.pageY)

    LiftHue {dimensions, position} ->
      { model | hueDrag = Drag.lift dimensions position model.hueDrag }
        |> handleMove (round position.pageX) (round position.pageY)

    Move (x, y) ->
      handleMove x y model

    Click pressed ->
      (handleClick pressed model, Cmd.none)

    Tasks _ ->
      (model, Cmd.none)

{-| Renders a color panel. -}
view : Model -> Html.Html Action
view model =
  render model
  -- Html.Lazy.lazy render model

-- Render internal
render : Model -> Html.Html Action
render model =
  let
    background =
      "hsla(" ++ (toString (round (model.value.hue * 360))) ++ ", 100%, 50%, 1)"

    color =
      model.value

    colorTransparent =
      (Ext.Color.toCSSRgba { color | alpha = 0 })

    colorFull =
      (Ext.Color.toCSSRgba { color | alpha = 1 })

    gradient =
      "linear-gradient(90deg, " ++ colorTransparent ++ "," ++ colorFull ++ ")"

    asPercent value =
      (toString (value * 100)) ++ "%"

    action act =
      Ui.enabledActions model
        [ onWithDimensions "mousedown" False act ]
  in
    node "ui-color-panel" [ classList [ ("disabled", model.disabled)
                                      , ("readonly", model.readonly)
                                      ]
                          ]
      [ div []
        [ node "ui-color-panel-rect"
            ([ style [ ("background-color", background )
                     , ("cursor", if model.drag.dragging then "move" else "" )
                     ]
             ] ++ (action LiftRect))
            [ renderHandle
              (asPercent (1 - color.value))
              (asPercent color.saturation) ]
        , node "ui-color-panel-hue"
            ([ style [("cursor", if model.hueDrag.dragging then "move" else "" )]
            ] ++ (action LiftHue))
            [ renderHandle (asPercent color.hue) "" ]
        ]
      , node "ui-color-panel-alpha"
        ([ style [("cursor", if model.alphaDrag.dragging then "move" else "" )]
        ] ++ (action LiftAlpha))
        [ div [style [("background-image", gradient)]] []
        , renderHandle "" (asPercent color.alpha)
        ]
      ]

{-| Updates a color panel color by coordinates. -}
handleMove : Int -> Int -> Model -> (Model, Cmd Action)
handleMove x y model =
  let
    color =
      if model.drag.dragging then
        handleRect x y model.value model.drag
      else if model.hueDrag.dragging then
        handleHue x y model.value model.hueDrag
      else if model.alphaDrag.dragging then
        handleAlpha x y model.value model.alphaDrag
      else
        model.value
  in
    if model.value == color then
      (model, Cmd.none)
    else
      ({ model | value = color }
       , Emitter.send model.uid (encodeHsv model.value) )

{-| Updates a color panel, stopping the drags if the mouse isn't pressed. -}
handleClick : Bool -> Model -> Model
handleClick value model =
  let
    alphaDrag = Drag.handleClick value model.alphaDrag
    hueDrag = Drag.handleClick value model.hueDrag
    drag = Drag.handleClick value model.drag
  in
    if model.alphaDrag == alphaDrag &&
       model.hueDrag == hueDrag &&
       model.drag == drag then
      model
    else
      { model | alphaDrag = alphaDrag
              , hueDrag = hueDrag
              , drag = drag  }

{-| Sets the vale of a color panel. -}
setValue : Color -> Model -> Model
setValue color model =
  { model | value = Ext.Color.toHsv color }

-- Handles the hue drag
handleHue : Int -> Int -> Hsv -> Drag.Model -> Hsv
handleHue x y color drag =
  let
    { top } = Drag.relativePercentPosition x y drag
    hue = clamp 0 1 top
  in
    if color.hue == hue then
      color
    else
      { color | hue = hue }

-- Handles the value / saturation drag
handleRect : Int -> Int -> Hsv -> Drag.Model -> Hsv
handleRect x y color drag =
  let
    { top, left } = Drag.relativePercentPosition x y drag
    saturation = clamp 0 1 left
    value = 1 - (clamp 0 1 top)
  in
    if color.saturation == saturation &&
       color.value == value then
      color
    else
      { color | saturation = saturation, value = value }

-- Handles the alpha drag
handleAlpha : Int -> Int -> Hsv -> Drag.Model -> Hsv
handleAlpha x y color drag =
  let
    { left } = Drag.relativePercentPosition x y drag
    alpha = clamp 0 1 left
  in
    if color.alpha == alpha then
      color
    else
      { color | alpha = alpha }

-- Renders a handle
renderHandle : String -> String -> Html.Html Action
renderHandle top left =
  node "ui-color-panel-handle"
    [ style [ ("top", top)
            , ("left", left)
            ]
    ]
    []
