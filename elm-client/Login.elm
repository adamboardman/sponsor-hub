module Login exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h1, p, text, ul)
import Html.Attributes exposing (class, for, href)
import Html.Events exposing (onSubmit)
import Http
import Json.Decode exposing (Decoder, at, field, map2, string)
import Json.Encode as Encode
import Loading
import Types exposing (LoginForm, Model, Msg(..), Problem(..), Session, ValidatedField(..))


loginFieldsToValidate : List ValidatedField
loginFieldsToValidate =
    [ Email
    , Password
    ]


loggedIn : Model -> Bool
loggedIn model =
    String.length model.session.loginToken > 0


userIsAdmin : Model -> Bool
userIsAdmin model =
    loggedIn model && model.loggedInUser.permissions > 1


pageLogin : Model -> List (Html Msg)
pageLogin model =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ div [ class "col-md-6 offset-md-3 col-xs-12" ]
                [ h1 [ class "text-xs-center" ] [ text "Login" ]
                , p [ class "text-xs-center" ]
                    [ if loggedIn model then
                        a [ href "#logout" ]
                            [ text "Logout" ]

                      else
                        a [ href "#register" ]
                            [ text "Need an account?" ]
                    ]
                , if loggedIn model then
                    text "Already logged in"

                  else
                    viewLoginForm model
                ]
            ]
        ]
    ]


viewLoginForm : Model -> Html Msg
viewLoginForm model =
    Form.form [ onSubmit SubmittedLoginForm ]
        [ Form.group []
            [ Form.label [ for "email" ] [ text "Email address" ]
            , Input.email
                [ Input.id "email"
                , Input.placeholder "Email"
                , Input.onInput EnteredLoginEmail
                , Input.value model.loginForm.email
                ]
            , Form.invalidFeedback [] [ text "Please enter your email address" ]
            ]
        , Form.group []
            [ Form.label [ for "password" ] [ text "Password" ]
            , Input.password
                [ Input.id "password"
                , Input.placeholder "Password"
                , Input.onInput EnteredLoginPassword
                , Input.value model.loginForm.password
                ]
            , Form.invalidFeedback [] [ text "Please enter your password" ]
            ]
        , ul [ class "error-messages" ]
            (List.map viewProblem model.problems)
        , Button.button [ Button.primary ]
            [ text "Sign in" ]
        , Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading
        ]


type LoginTrimmedForm
    = LoginTrimmed LoginForm


loginTrimFields : LoginForm -> LoginTrimmedForm
loginTrimFields form =
    LoginTrimmed
        { email = String.trim form.email
        , password = String.trim form.password
        }


loginUpdateForm : (LoginForm -> LoginForm) -> Model -> ( Model, Cmd Msg )
loginUpdateForm transform model =
    ( { model | loginForm = transform model.loginForm }, Cmd.none )


loginValidate : LoginForm -> Result (List Problem) LoginTrimmedForm
loginValidate form =
    let
        trimmedForm =
            loginTrimFields form
    in
    case List.concatMap (validateField trimmedForm) loginFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : LoginTrimmedForm -> ValidatedField -> List Problem
validateField (LoginTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Email ->
                if String.isEmpty form.email then
                    [ "email can't be blank." ]

                else
                    []

            Password ->
                if String.isEmpty form.password then
                    [ "password can't be blank." ]

                else
                    []

            _ ->
                []



-- HTTP


login : LoginTrimmedForm -> Cmd Msg
login (LoginTrimmed form) =
    let
        body =
            Encode.object [ ( "email", Encode.string form.email ), ( "password", Encode.string form.password ) ]
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , url = "api/auth/login"
        , expect = Http.expectJson CompletedLogin loginDecoder
        , headers = []
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


loginDecoder : Decoder Session
loginDecoder =
    map2 Session
        (at [ "expire" ] string)
        (at [ "token" ] string)
