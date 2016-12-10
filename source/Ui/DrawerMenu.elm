module Ui.DrawerMenu exposing (Model, Msg, init, update, view, viewRow, viewRowDefault, toggle)

import Ui
import Html exposing (Html, node, text, a)
import Html.Attributes exposing (classList, style, href, class)
import Html.Events exposing (onClick)


type alias Model =
    { isVisible : Bool
    }


init : Model
init =
    { isVisible = False
    }


type Msg
    = Toggle


update : Msg -> Model -> Model
update msg model =
    case msg of
        Toggle ->
            { model | isVisible = not model.isVisible }


view : Model -> List (Html msg) -> Html msg
view model rows =
    let
        visibility =
            if model.isVisible then
                class "ui-drawermenu-visible"
            else
                class ""
    in
        node
            "ui-drawermenu"
            [ visibility ]
            rows


viewRow : List (Html msg) -> Maybe String -> Maybe msg -> Html msg
viewRow childList glyph action =
    let
        icon =
            case glyph of
                Just aGlyph ->
                    Ui.icon aGlyph False []

                Nothing ->
                    text ""
        attributes =
          case action of
            Nothing ->
              []
            Just msg ->
              [ onClick msg ]
    in
        node
            "ui-drawermenu-item"
            attributes
            (childList ++ [ icon ])


viewRowDefault : String -> Maybe String -> Maybe msg -> Html msg
viewRowDefault content glyph action =
    viewRow
        [ text content ]
        glyph
        action


toggle : Model -> Model
toggle model =
    update Toggle model
