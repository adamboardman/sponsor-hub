module Register exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h1, p, text, ul)
import Html.Attributes exposing (class, for, href)
import Html.Events exposing (onSubmit)
import Http
import Json.Encode as Encode
import Loading
import Types exposing (ApiActionResponse, LoginForm, Model, Msg(..), Problem(..), RegisterForm, Session, ValidatedField(..), apiActionDecoder)


registerFieldsToValidate : List ValidatedField
registerFieldsToValidate =
    [ Email
    , Password
    , ConfirmPassword
    ]


pageRegister : Model -> Maybe String -> List (Html Msg)
pageRegister model email =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ div [ class "col-md-6 offset-md-3 col-xs-12" ]
                [ h1 [ class "text-xs-center" ]
                    [ if email == Maybe.Nothing then
                        text "Register"

                      else
                        text "Enter Password"
                    ]
                , p [ class "text-xs-center" ]
                    [ if email == Maybe.Nothing then
                        a [ href "#login" ]
                            [ text "Have an account?" ]

                      else
                        text ""
                    ]
                , if model.apiActionResponse.resourceId == 0 then
                    viewRegisterForm model email

                  else if email == Maybe.Nothing then
                    text "Please check your email (inc spam folder) and click the confirmation link"

                  else
                    text "Please login"
                ]
            ]
        ]
    ]


viewRegisterForm : Model -> Maybe String -> Html Msg
viewRegisterForm model email =
    Form.form [ onSubmit SubmittedRegisterForm ]
        [ Form.group []
            [ Form.label [ for "email" ] [ text "Email address" ]
            , Input.email
                [ Input.id "email"
                , Input.placeholder "Email"
                , Input.onInput EnteredRegisterEmail
                , Input.value (Maybe.withDefault model.registerForm.email email)
                , if email == Maybe.Nothing then
                    Input.disabled False

                  else
                    Input.disabled True
                ]
            , Form.invalidFeedback [] [ text "Please enter your email address" ]
            ]
        , Form.group []
            [ Form.label [ for "password" ] [ text "Password" ]
            , Input.password
                [ Input.id "password"
                , Input.placeholder "Password"
                , Input.onInput EnteredRegisterPassword
                , Input.value model.registerForm.password
                ]
            , Form.invalidFeedback [] [ text "Please enter your password" ]
            ]
        , Form.group []
            [ Form.label [ for "passwordConfirm" ] [ text "Confirm Password" ]
            , Input.password
                [ Input.id "passwordConfirm"
                , Input.placeholder "Confirm your password"
                , Input.onInput EnteredRegisterConfirmPassword
                , Input.value model.registerForm.password_confirm
                ]
            , Form.invalidFeedback [] [ text "Please enter your password again" ]
            ]
        , ul [ class "error-messages" ]
            (List.map viewProblem model.problems)
        , Button.button [ Button.primary ]
            [ text "Register" ]
        , Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading
        ]


registerUpdateForm : (RegisterForm -> RegisterForm) -> Model -> ( Model, Cmd Msg )
registerUpdateForm transform model =
    ( { model | registerForm = transform model.registerForm }, Cmd.none )


registerValidate : RegisterForm -> Result (List Problem) RegisterTrimmedForm
registerValidate form =
    let
        trimmedForm =
            registerTrimFields form
    in
    case List.concatMap (validateField trimmedForm) registerFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : RegisterTrimmedForm -> ValidatedField -> List Problem
validateField (RegisterTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Email ->
                if String.isEmpty form.email then
                    [ "email can't be blank." ]

                else if String.contains "@" form.email then
                    []

                else
                    [ "email must contain '@'" ]

            Password ->
                if String.isEmpty form.password then
                    [ "password can't be blank." ]

                else if form.password == form.password_confirm then
                    []

                else
                    [ "passwords must match" ]

            ConfirmPassword ->
                if String.isEmpty form.password then
                    [ "confirm password can't be blank." ]

                else
                    []

            _ ->
                []


type RegisterTrimmedForm
    = RegisterTrimmed RegisterForm


registerTrimFields : RegisterForm -> RegisterTrimmedForm
registerTrimFields form =
    RegisterTrimmed
        { email = String.trim form.email
        , password = String.trim form.password
        , password_confirm = String.trim form.password_confirm
        , verification = String.trim form.verification
        }



-- HTTP


register : RegisterTrimmedForm -> Cmd Msg
register (RegisterTrimmed form) =
    let
        body =
            Encode.object
                [ ( "email", Encode.string form.email )
                , ( "verification", Encode.string form.verification )
                , ( "password", Encode.string form.password )
                , ( "password_confirmation", Encode.string form.password_confirm )
                ]
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , url = "api/auth/register"
        , expect = Http.expectJson GotRegisterJson apiActionDecoder
        , headers = []
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }
