module FormValidation exposing (viewProblem)

import Html exposing (Html, li, text)
import Types exposing (Problem(..), ValidatedField(..))


viewProblem : Problem -> Html msg
viewProblem problem =
    let
        errorMessage =
            case problem of
                InvalidEntry _ str ->
                    str

                ServerError str ->
                    str
    in
    li [] [ text errorMessage ]
