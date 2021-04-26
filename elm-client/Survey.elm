module Survey exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Checkbox as Checkbox
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h1, li, p, text, ul)
import Html.Attributes exposing (class, for, href)
import Html.Events exposing (onSubmit)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Json.Encode as Encode
import Loading exposing (LoadingState(..))
import Set exposing (Set)
import Types exposing (ApiActionResponse, Model, Msg(..), Problem(..), SponsorableUser, Survey, SurveyForm, SurveySponsor, User, ValidatedField(..), apiActionDecoder, authHeader, sponsorableUserDecoder, surveySponsorDecoder)


surveyFieldsToValidate : List ValidatedField
surveyFieldsToValidate =
    [ Name
    , Email
    ]


pageViewSurvey : Model -> List (Html Msg)
pageViewSurvey model =
    [ div [ class "container page" ]
        [ div [ class "row" ]
            [ h1 [ class "text-xs-center" ] [ text "Edit Survey" ] ]
        , div [ class "text-xs-center" ]
            [ case model.loading of
                On ->
                    Loading.render Loading.DoubleBounce Loading.defaultConfig model.loading

                Off ->
                    viewSurvey model
            ]
        ]
    ]


viewSurvey : Model -> Html Msg
viewSurvey model =
    div []
        [ p []
            [ text "Name: "
            , text model.survey.name
            , text "("
            , text (String.fromInt model.survey.user_id)
            , text ") "
            ]
        , p [] [ text "GH: ", text model.survey.github_id ]
        , p [ class "survey-title" ] [ text "Priorities" ]
        , p [] [ text model.survey.priorities ]
        , p [ class "survey-title" ] [ text "Issues" ]
        , p [] [ text model.survey.issues ]
        , p [ class "survey-title" ] [ text "Communications frequency" ]
        , p [] [ text model.survey.comms_frequency ]
        , case model.survey.pre_release of
            True ->
                p [ class "survey-title" ] [ text "Would like pre-release builds" ]

            False ->
                p [] [ text "" ]
        , p [ class "survey-title" ] [ text "Privacy" ]
        , p [] [ text model.survey.privacy ]
        , p [ class "p-md-5" ] [ text "" ]
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
            [ Form.label [] [ text "Users" ]
            , p [ class "clarification" ] [ text "Who can view your survey, you must include anyone your sponsoring and anyone else you wish to influence" ]
            , ul []
                (List.map (viewSponsorableUser model.surveyForm.sponsored_users) model.sponsorableUsers)
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
                , Textarea.value model.surveyForm.priorities
                ]
            , Form.invalidFeedback [] [ text "Please enter your priorities" ]
            ]
        , Form.group []
            [ Form.label [ for "issues" ] [ text "Issues" ]
            , p [ class "clarification" ]
                [ text "Please raise issues for each of your prioritised items. On the "
                , a [ href "https://github.com/gemian/gemian/issues" ] [ text "GitHub Issues Tracker" ]
                , text ", then use the same prioritisation schema as above. (Optional)"
                ]
            , p [ class "example" ] [ text "eg: 1. https://github.com/gemian/gemian/issues/3, 2. https://github.com/gemian/gemian/issues/5" ]
            , p [ class "example" ] [ text "or: 60% https://github.com/gemian/gemian/issues/3, 40% https://github.com/gemian/gemian/issues/5" ]
            , Textarea.textarea
                [ Textarea.id "issues"
                , Textarea.rows 4
                , Textarea.onInput EnteredSurveyIssues
                , Textarea.value model.surveyForm.issues
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
                , Textarea.value model.surveyForm.comms_frequency
                ]
            , Form.invalidFeedback [] [ text "Please enter your communications frequency preferences" ]
            ]
        , Form.group []
            [ Form.label [ for "preRelease" ] [ text "Pre-Release builds" ]
            , p [ class "clarification" ] [ text "Would you like to be invited (probably by email: ", text model.loggedInUser.email, text ") to test pre-release builds." ]
            , Checkbox.checkbox
                [ Checkbox.id "preRelease"
                , Checkbox.onCheck EnteredSurveyPreRelease
                , Checkbox.checked model.surveyForm.pre_release
                ]
                "Invite me to pre-release builds"
            , Form.invalidFeedback [] [ text "Please enter your communications frequency preferences" ]
            ]
        , Form.group []
            [ Form.label [ for "privacy" ] [ text "Privacy" ]
            , p [ class "clarification" ] [ text "How private do you consider your donation amount to be." ]
            , p [ class "example" ] [ text "Answers given so far indicate that we should not make use of the Goals feature as it shows a % progress bar to goal target thus allowing fine grained calculation of totals which could be used to figure out individual supporters sponsorship levels by noting it and additions/removals over time." ]
            , p [ class "example" ] [ text "So you only need to answer this if you object to occasional ranged $/month totals, eg 32-64, 64-128, 128-256." ]
            , Textarea.textarea
                [ Textarea.id "privacy"
                , Textarea.onInput EnteredSurveyPrivacy
                , Textarea.value model.surveyForm.privacy
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
        , user_id = form.user_id
        , name = String.trim form.name
        , sponsored_users = form.sponsored_users
        , github_id = String.trim form.github_id
        , priorities = String.trim form.priorities
        , issues = String.trim form.issues
        , comms_frequency = String.trim form.comms_frequency
        , pre_release = form.pre_release
        , privacy = String.trim form.privacy
        }


viewSponsorableUser : Set Int -> SponsorableUser -> Html Msg
viewSponsorableUser sponsoredList user =
    li []
        [ Form.label [ for (String.fromInt user.id) ]
            [ Checkbox.checkbox
                [ Checkbox.id (String.fromInt user.id)
                , Checkbox.checked (Set.member user.id sponsoredList)
                , Checkbox.onCheck (EnteredUserToAddSponsor user.id)
                ]
                (user.name ++ " (" ++ user.github_id ++ ")")
            ]
        ]



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


loadSponsorsForSurveys : Model -> Cmd Msg
loadSponsorsForSurveys model =
    Http.request
        { method = "GET"
        , url = "api/surveys/" ++ String.fromInt model.survey.id ++ "/sponsors"
        , expect = Http.expectJson LoadedSponsorsForSurvey sponsorsListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


sponsorsListDecoder : Decoder (List SurveySponsor)
sponsorsListDecoder =
    list surveySponsorDecoder


loadSponsorableUsers : Model -> Cmd Msg
loadSponsorableUsers model =
    Http.request
        { method = "GET"
        , url = "api/sponsorable"
        , expect = Http.expectJson LoadedSponsorableUsers sponsorableUsersListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


sponsorableUsersListDecoder : Decoder (List SponsorableUser)
sponsorableUsersListDecoder =
    list sponsorableUserDecoder


updateServerWithSponsorState : Model -> Int -> Bool -> Cmd Msg
updateServerWithSponsorState model sponsorId sponsorState =
    let
        body =
            case sponsorState of
                True ->
                    Encode.object [ ( "userId", Encode.int sponsorId ) ]
                        |> Http.jsonBody

                False ->
                    emptyBody
    in
    Http.request
        { method =
            case sponsorState of
                True ->
                    "POST"

                False ->
                    "DELETE"
        , url =
            case sponsorState of
                True ->
                    "api/surveys/" ++ String.fromInt model.surveyForm.id ++ "/sponsors"

                False ->
                    "api/surveys/" ++ String.fromInt model.surveyForm.id ++ "/sponsors/" ++ String.fromInt sponsorId
        , expect = Http.expectJson GotUpdateSurveyWithSponsorStateJson apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }
