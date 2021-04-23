module SurveysList exposing (..)

import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h4, span, text)
import Html.Attributes exposing (class, href)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Types exposing (Model, Msg(..), Survey, authHeader, surveyDecoder)


pageSurveysList : Model -> List (Html Msg)
pageSurveysList model =
    [ h4 [] [ text "Surveys" ]
    , div [] (List.map (surveysSummary model) model.surveysList)
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
