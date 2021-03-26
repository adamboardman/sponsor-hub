module SurveysList exposing (..)

import FormValidation exposing (viewProblem)
import Html exposing (Html, a, div, h4, text)
import Html.Attributes exposing (href)
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
        [ text survey.github_id
        , text "("
        , text (String.fromInt survey.user_id)
        , text ") "
        , text survey.name
        --, a [ href ("#surveys/" ++ String.fromInt survey.id ++ "/edit") ]
        --    [ text "(edit)" ]
        , a [ href ("#surveys/" ++ String.fromInt survey.id) ]
            [ text "(view)" ]
        ]


-- HTTP


loadSurveys : Model -> Cmd Msg
loadSurveys model =
    Http.request
        { method = "GET"
        , url = "/api/surveys"
        , expect = Http.expectJson LoadedSurveys surveyListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


surveyListDecoder : Decoder (List Survey)
surveyListDecoder =
    list surveyDecoder

