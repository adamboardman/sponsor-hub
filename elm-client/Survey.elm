module Survey exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import FormValidation exposing (viewProblem)
import Html exposing (Html, div, h1, p, text, ul)
import Html.Attributes exposing (class, for)
import Html.Events exposing (onSubmit)
import Http
import Json.Encode as Encode
import Loading exposing (LoadingState(..))
import Types exposing (ApiActionResponse, Model, Msg(..), Problem(..), SurveyForm, User, ValidatedField(..), apiActionDecoder, authHeader)


surveyFieldsToValidate : List ValidatedField
surveyFieldsToValidate =
    [ Name
    , Email
    ]


pageSurvey : Model -> List (Html Msg)
pageSurvey model =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ h1 [ class "text-xs-center" ] [ text "Edit Survey" ] ]
        , div [ class "text-xs-center" ]
            [ case model.loading of
                On ->
                    Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading

                Off ->
                    viewSurveyForm model
            ]
        ]
    ]


viewSurveyForm : Model -> Html Msg
viewSurveyForm model =
    Form.form [ onSubmit SubmittedSurveyForm ]
        [ Form.group []
            [ Form.label [ for "name" ] [ text "Your Name" ]
            , p [ class "clarification" ] [ text "If we were ever to meet you in person, how would you like to be referred to." ]
            , Input.text
                [ Input.id "name"
                , Input.placeholder "Name"
                , Input.onInput EnteredSurveyName
                , Input.value model.surveyForm.name
                ]
            , Form.invalidFeedback [] [ text "Please enter your name" ]
            ]
        , Form.group []
            [ Form.label [ for "gitHubId" ] [ text "GitHub UserID" ]
            , p [ class "clarification" ] [ text "Your GitHub user id is used to confirm who you are sponsoring." ]
            , Input.text
                [ Input.id "gitHubId"
                , Input.placeholder "UserID"
                , Input.onInput EnteredSurveyGitHubUserId
                , Input.value model.surveyForm.github_id
                ]
            , Form.invalidFeedback [] [ text "Please enter your user id" ]
            ]
        , Form.group []
            [ Form.label [ for "priorities" ] [ text "Priorities" ]
            , p [ class "clarification" ] [ text "Free form text for you to indicate any preference you might have for priorities for future work, it could be an ordered list of targets, or percentage based." ]
            , p [ class "example" ] [ text "eg: 1. Gemian on Cosmo Sleep battery performance, 2. Cosmo Bluetooth, 3. Login with GitHub id to this survey" ]
            , p [ class "example" ] [ text "or: 40% Gemian on Cosmo, 20% Back porting improvements to Gemini, 40% Mainline Kernel efforts" ]
            , Textarea.textarea
                [ Textarea.id "priorities"
                , Textarea.rows 4
                , Textarea.onInput EnteredSurveyPriorities
                , Textarea.value model.surveyForm.priorities
                ]
            , Form.invalidFeedback [] [ text "Please enter your priorities" ]
            ]
        , Form.group []
            [ Form.label [ for "commsFrequency" ] [ text "Communications Frequency" ]
            , p [ class "clarification" ] [ text "Free form text for you to indicate your max and min communications frequency." ]
            , p [ class "example" ] [ text "from: no more than one email per week and at least one email every two months" ]
            , p [ class "example" ] [ text "to: just if there is some significant progress to report" ]
            , Textarea.textarea
                [ Textarea.id "commsFrequency"
                , Textarea.onInput EnteredSurveyCommsFrequency
                , Textarea.value model.surveyForm.comms_frequency
                ]
            , Form.invalidFeedback [] [ text "Please enter your communications frequency preferences" ]
            ]
        , Form.group []
            [ Form.label [ for "privacy" ] [ text "Privacy" ]
            , p [ class "clarification" ] [ text "How private do you consider your donation amount to be." ]
            , p [ class "example" ] [ text "from: you should do your best to keep it private" ]
            , p [ class "example" ] [ text "to: I don't mind if people could work it out from viewing totals over time and seeing who recently appeared/disappeared as a sponsor." ]
            , Textarea.textarea
                [ Textarea.id "commsFrequency"
                , Textarea.onInput EnteredSurveyPrivacy
                , Textarea.value model.surveyForm.privacy
                ]
            , Form.invalidFeedback [] [ text "Please enter your communications frequency preferences" ]
            ]
        , ul [ class "error-messages" ]
            (List.map viewProblem model.problems)
        , Button.button [ Button.primary ]
            [ text "Update Survey" ]
        , Loading.render Loading.DoubleBounce Loading.defaultConfig model.saving
        , p [ class "p-md-5" ] [ text "" ]
        ]


surveyUpdateForm : (SurveyForm -> SurveyForm) -> Model -> ( Model, Cmd Msg )
surveyUpdateForm transform model =
    ( { model | surveyForm = transform model.surveyForm }, Cmd.none )


surveyValidate : SurveyForm -> Result (List Problem) SurveyTrimmedForm
surveyValidate form =
    let
        trimmedForm =
            surveyTrimFields form
    in
    case List.concatMap (validateField trimmedForm) surveyFieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : SurveyTrimmedForm -> ValidatedField -> List Problem
validateField (SurveyTrimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Name ->
                if String.isEmpty form.name then
                    [ "name can't be blank." ]

                else
                    []

            GitHubId ->
                if String.isEmpty form.github_id then
                    [ "GitHub Id can't be blank." ]

                else
                    []

            _ ->
                []


type SurveyTrimmedForm
    = SurveyTrimmed SurveyForm


surveyTrimFields : SurveyForm -> SurveyTrimmedForm
surveyTrimFields form =
    SurveyTrimmed
        { id = form.id
        , name = String.trim form.name
        , github_id = String.trim form.github_id
        , priorities = String.trim form.priorities
        , comms_frequency = String.trim form.comms_frequency
        , privacy = String.trim form.privacy
        }



-- HTTP


survey : String -> SurveyTrimmedForm -> Cmd Msg
survey token (SurveyTrimmed form) =
    let
        body =
            Encode.object
                [ ( "Name", Encode.string form.name )
                , ( "GitHubId", Encode.string form.github_id )
                , ( "Priorities", Encode.string form.priorities )
                , ( "CommsFrequency", Encode.string form.comms_frequency )
                , ( "Privacy", Encode.string form.privacy )
                ]
                |> Http.jsonBody

        method =
            case form.id of
                0 ->
                    "POST"

                _ ->
                    "PUT"

        url =
            case form.id of
                0 ->
                    "/api/surveys"

                _ ->
                    "/api/surveys/" ++ String.fromInt form.id
    in
    Http.request
        { method = method
        , url = url
        , expect = Http.expectJson GotUpdateSurveyJson apiActionDecoder
        , headers = [ authHeader token ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }
