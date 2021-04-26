module SurveysList exposing (..)

import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h2, h4, p, span, text)
import Html.Attributes exposing (class, href)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Types exposing (Model, Msg(..), PreReleaseUser, Survey, SurveySponsor, authHeader, preReleaseUserDecoder, surveyDecoder)


pageSurveysList : Model -> List (Html Msg)
pageSurveysList model =
    [ p [] [ text "" ]
    , h4 [] [ text "Surveys" ]
    , div [] (List.map (surveysSummary model) model.surveysList)
    , p [] [ text "" ]
    , if model.loggedInUser.permissions >= 3 then
        div []
            [ h2 [] [ text "Pre-Release Requested" ]
            , p [] [ text "Remember to use BCC" ]
            , div [] (List.map (preReleaseEmailSummary model) model.preReleaseUsers)
            ]

      else
        text ""
    , div [] (List.map viewProblem model.problems)
    ]


surveysSummary : Model -> Survey -> Html Msg
surveysSummary model survey =
    div []
        [ span [ class "survey-title" ] [ text survey.name ]
        , text " "
        , text survey.github_id
        , text "("
        , text (String.fromInt survey.user_id)
        , text ") "
        , a [ href ("#surveys/" ++ String.fromInt survey.id) ]
            [ text "(view)" ]
        , if model.loggedInUser.permissions >= 3 then
            a [ href ("#surveys/" ++ String.fromInt survey.id ++ "/edit") ]
                [ text "(edit)" ]

          else
            text ""
        ]


preReleaseEmailSummary : Model -> PreReleaseUser -> Html Msg
preReleaseEmailSummary model user =
    div []
        [ span [ class "survey-title" ] [ text user.name ]
        , text " <"
        , text user.email
        , text ">, "
        ]



-- HTTP


loadSurveys : Model -> Cmd Msg
loadSurveys model =
    Http.request
        { method = "GET"
        , url = "api/surveys"
        , expect = Http.expectJson LoadedSurveys surveyListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


surveyListDecoder : Decoder (List Survey)
surveyListDecoder =
    list surveyDecoder


loadPreReleaseUsers : Model -> Cmd Msg
loadPreReleaseUsers model =
    Http.request
        { method = "GET"
        , url = "api/prereleaseusers"
        , expect = Http.expectJson LoadedPreReleaseUsers preReleaseUsersListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


preReleaseUsersListDecoder : Decoder (List PreReleaseUser)
preReleaseUsersListDecoder =
    list preReleaseUserDecoder
