module Main exposing (Model, Msg(..), init, main, update, view)

import Bootstrap.Button as Button
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Row as Row
import Bootstrap.Navbar as Navbar
import Bootstrap.Utilities.Spacing as Spacing
import Browser
import Browser.Events as Events
import Html exposing (..)
import Html.Attributes as Attr exposing (..)
import Html.Events exposing (onClick)
import Http exposing (..)
import Json.Decode as Decode


main =
    Browser.element { init = init, subscriptions = subscriptions, update = update, view = view }



-- MODEL


type State
    = Question
    | Answer


type GameType
    = Kuulamine
    | Nimetamine


type NumberType
    = PohiNimetav
    | JargNimetav
    | JargAlalutlev


type alias Model =
    { quiz : Quiz
    , gameType : GameType
    , numberType : NumberType
    , state : State
    , loaded : Bool
    , navbarState : Navbar.State
    }


getQuizNumber model =
    case model.numberType of
        PohiNimetav ->
            model.quiz.pohiNimetav

        JargNimetav ->
            model.quiz.jargNimetav

        JargAlalutlev ->
            model.quiz.jargAlalutlev


nextState : State -> State
nextState state =
    case state of
        Question ->
            Answer

        Answer ->
            Question


init : () -> ( Model, Cmd Msg )
init _ =
    let
        ( navbarState, navbarCmd ) =
            Navbar.initialState NavbarMsg
    in
    ( { quiz = defaultQuiz, gameType = Kuulamine, numberType = JargAlalutlev, state = Answer, loaded = True, navbarState = navbarState }, navbarCmd )


defaultQuiz =
    { n = 1, jargAlalutlev = "esimesel", jargNimetav = "esimene", pohiNimetav = "üks" }



-- UPDATE


type alias Quiz =
    { n : Int
    , pohiNimetav : String
    , jargNimetav : String
    , jargAlalutlev : String
    }


type Msg
    = NextMsg
    | NavbarMsg Navbar.State
    | GotQuizMsg (Result Http.Error Quiz)
    | SetupGameMsg GameType NumberType
    | KeyPressMsg String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NextMsg ->
            let
                newModel =
                    { model | state = nextState model.state }
            in
            if newModel.state == Question then
                ( { newModel | loaded = False }, getNumber )

            else
                ( newModel, Cmd.none )

        SetupGameMsg gameType numberType ->
            ( { model | gameType = gameType, numberType = numberType }, Cmd.none )

        GotQuizMsg result ->
            case result of
                Ok q ->
                    ( { model | quiz = q, loaded = True }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        NavbarMsg state ->
            ( { model | navbarState = state }, Cmd.none )

        KeyPressMsg key ->
            case key of
                " " ->
                    update NextMsg model

                _ ->
                    ( model, Cmd.none )


quizDecoder : Decode.Decoder Quiz
quizDecoder =
    Decode.map4 Quiz
        (Decode.field "N" Decode.int)
        (Decode.field "QuantitiveNominative" Decode.string)
        (Decode.field "OrdinalNominative" Decode.string)
        (Decode.field "OrdinalAdessive" Decode.string)


getNumber =
    Http.get
        { url = "/next", expect = Http.expectJson GotQuizMsg quizDecoder }



-- VIEW


mp3url n =
    if n == "" then
        ""

    else
        "media/" ++ n ++ ".mp3"


showAnswer : Model -> Html Msg
showAnswer model =
    h1 [ Spacing.p5, classList [ ( "invisible", not model.loaded || (model.state == Question && model.gameType == Kuulamine) ), ( "text-center", True ) ] ]
        [ text
            (case ( model.gameType, model.state ) of
                ( Kuulamine, _ ) ->
                    String.fromInt model.quiz.n

                ( Nimetamine, Question ) ->
                    String.fromInt model.quiz.n

                ( Nimetamine, Answer ) ->
                    getQuizNumber model
            )
        ]


menu : Model -> Html Msg
menu model =
    Navbar.config NavbarMsg
        |> Navbar.withAnimation
        |> Navbar.brand [ href "#" ] [ text "Numbrid" ]
        |> Navbar.items
            [ Navbar.dropdown
                { id = "dropdowny"
                , toggle = Navbar.dropdownToggle [] [ span [] [ text "Harjutused" ] ]
                , items =
                    [ Navbar.dropdownItem [ href "#", onClick (SetupGameMsg Kuulamine PohiNimetav) ] [ text "Põhiarvsõnad kuulamine (nimetav)" ]
                    , Navbar.dropdownItem [ href "#", onClick (SetupGameMsg Kuulamine JargNimetav) ] [ text "Järgarvsõnad kuulamine (nimetav)" ]
                    , Navbar.dropdownItem [ href "#", onClick (SetupGameMsg Kuulamine JargAlalutlev) ] [ text "Järgarvsõnad kuulamine (alalütlev)" ]
                    , Navbar.dropdownItem [ href "#", onClick (SetupGameMsg Nimetamine PohiNimetav) ] [ text "Põhiarvsõnad nimetamine (nimetav)" ]
                    , Navbar.dropdownItem [ href "#", onClick (SetupGameMsg Nimetamine JargNimetav) ] [ text "Järgarvsõnad nimetamine (nimetav)" ]
                    , Navbar.dropdownItem [ href "#", onClick (SetupGameMsg Nimetamine JargAlalutlev) ] [ text "Järgarvsõnad nimetamine (alalütlev)" ]
                    ]
                }
            ]
        |> Navbar.view model.navbarState


actionButton model =
    Button.button [ Button.primary, Button.onClick NextMsg ]
        [ text
            (if model.state == Answer then
                "Next"

             else
                "Answer"
            )
        ]


none =
    text ""


viewAudio : Model -> Html Msg
viewAudio model =
    let
        audioEl =
            audio [ src (mp3url (getQuizNumber model)), controls False, autoplay True ] []
    in
    if not model.loaded then
        none

    else
        case ( model.gameType, model.state ) of
            ( Kuulamine, Question ) ->
                audioEl

            ( Kuulamine, Answer ) ->
                none

            ( Nimetamine, Question ) ->
                none

            ( Nimetamine, Answer ) ->
                audioEl


viewQuiz : Model -> Html Msg
viewQuiz model =
    Grid.container []
        [ viewAudio model
        , showAnswer model
        , div [ class "text-center" ]
            [ actionButton model ]
        ]


view : Model -> Html Msg
view model =
    div []
        [ menu model
        , viewQuiz model
        ]



-- SUBSCRIPTIONS


keyDecoder : Decode.Decoder Msg
keyDecoder =
    Decode.map KeyPressMsg (Decode.field "key" Decode.string)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Events.onKeyPress keyDecoder
        , Navbar.subscriptions model.navbarState NavbarMsg
        ]
