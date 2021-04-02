module Survey exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Checkbox as Checkbox
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h1, p, text, ul)
import Html.Attributes exposing (class, for, href)
import Html.Events exposing (onSubmit)
import Http
import Json.Encode as Encode
import Loading exposing (LoadingState(..))
import Types exposing (ApiActionResponse, Model, Msg(..), Problem(..), Survey, User, ValidatedField(..), apiActionDecoder, authHeader)


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
                , Input.value model.survey.name
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
                , Input.value model.survey.github_id
                ]
            , Form.invalidFeedback [] [ text "Please enter your user id" ]
            ]
        , Form.group []
            [ Form.label [ for "priorities" ] [ text "Priorities" ]
            , p [ class "clarification" ] [ text "Free form text for you to indicate any preference you might have for priorities for future work, it could be an ordered list of targets, or percentage based. (Optional)" ]
            , p [ class "example" ] [ text "eg: 1. Gemian on Cosmo Sleep battery performance, 2. Cosmo Bluetooth, 3. Login with GitHub id to this survey" ]
            , p [ class "example" ] [ text "or: 40% Gemian on Cosmo, 20% Back porting improvements to Gemini, 40% Mainline Kernel efforts" ]
            , Textarea.textarea
                [ Textarea.id "priorities"
                , Textarea.rows 4
                , Textarea.onInput EnteredSurveyPriorities
                , Textarea.value model.survey.priorities
                ]
            , Form.invalidFeedback [] [ text "Please enter your priorities" ]
            ]
        , Form.group []
            [ Form.label [ for "issues" ] [ text "Issues" ]
            , p [ class "clarification" ] [ text "Please raise issues for each of your prioritised items. On the "
            , a [ href "https://github.com/gemian/gemian/issues" ][ text "GitHub Issues Tracker"]
            , text ", then use the same prioritisation schema as above. (Optional)"
            ]
            , p [ class "example" ] [ text "eg: 1. https://github.com/gemian/gemian/issues/3, 2. https://github.com/gemian/gemian/issues/5" ]
            , p [ class "example" ] [ text "or: 60% https://github.com/gemian/gemian/issues/3, 40% https://github.com/gemian/gemian/issues/5" ]
            , Textarea.textarea
                [ Textarea.id "issues"
                , Textarea.rows 4
                , Textarea.onInput EnteredSurveyIssues
                , Textarea.value model.survey.issues
                ]
            , Form.invalidFeedback [] [ text "Please list bug tracker issues" ]
            ]
        , Form.group []
            [ Form.label [ for "commsFrequency" ] [ text "Communications Frequency" ]
            , p [ class "clarification" ] [ text "Free form text for you to indicate your max and min communications frequency." ]
            , p [ class "example" ] [ text "from: no more than one email per week and at least one email every two months" ]
            , p [ class "example" ] [ text "to: just if there is some significant progress to report" ]
            , Textarea.textarea
                [ Textarea.id "commsFrequency"
                , Textarea.onInput EnteredSurveyCommsFrequency
                , Textarea.value model.survey.comms_frequency
                ]
            , Form.invalidFeedback [] [ text "Please enter your communications frequency preferences" ]
            ]
        , Form.group []
            [ Form.label [ for "preRelease" ] [ text "Pre-Release builds" ]
            , p [ class "clarification" ] [ text "Would you like to be invited (probably by email) to test pre-release builds." ]
            , Checkbox.checkbox
                  [ Checkbox.id "preRelease"
                  , Checkbox.onCheck EnteredSurveyPreRelease
                  , Checkbox.checked model.survey.pre_release
                  ]
                  "Invite me to pre-release builds"
            , Form.invalidFeedback [] [ text "Please enter your communications frequency preferences" ]
            ]
        , Form.group []
            [ Form.label [ for "privacy" ] [ text "Privacy" ]
            , p [ class "clarification" ] [ text "How private do you consider your donation amount to be." ]
            , p [ class "example" ] [ text "from: you should do your best to keep it private" ]
            , p [ class "example" ] [ text "to: I don't mind if people could work it out from viewing totals over time and seeing who recently appeared/disappeared as a sponsor." ]
            , Textarea.textarea
                [ Textarea.id "privacy"
                , Textarea.onInput EnteredSurveyPrivacy
                , Textarea.value model.survey.privacy
                ]
            , Form.invalidFeedback [] [ text "Please enter your privacy preferences" ]
            ]
        , ul [ class "error-messages" ]
            (List.map viewProblem model.problems)
        , Button.button [ Button.primary ]
            [ text "Update Survey" ]
        , Loading.render Loading.DoubleBounce Loading.defaultConfig model.saving
        , p [ class "p-md-5" ] [ text "" ]
        ]


surveyUpdateForm : (Survey -> Survey) -> Model -> ( Model, Cmd Msg )
surveyUpdateForm transform model =
    ( { model | survey = transform model.survey }, Cmd.none )


surveyValidate : Survey -> Result (List Problem) SurveyTrimmedForm
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
    = SurveyTrimmed Survey


surveyTrimFields : Survey -> SurveyTrimmedForm
surveyTrimFields form =
    SurveyTrimmed
        { id = form.id
        , user_id =  form.user_id
        , name = String.trim form.name
        , github_id = String.trim form.github_id
        , priorities = String.trim form.priorities
        , issues = String.trim form.issues
        , comms_frequency = String.trim form.comms_frequency
        , pre_release = form.pre_release
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
                , ( "Issues", Encode.string form.issues )
                , ( "CommsFrequency", Encode.string form.comms_frequency )
                , ( "PreRelease", Encode.bool form.pre_release )
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
                    "api/surveys"

                _ ->
                    "api/surveys/" ++ String.fromInt form.id
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
