module Types exposing (..)

import Bootstrap.Navbar as Navbar
import Browser exposing (UrlRequest)
import Browser.Navigation as Nav
import FormatNumber.Locales exposing (Decimals(..), Locale)
import Http
import Json.Decode as Decode exposing (Decoder, bool, int, list, string)
import Json.Decode.Pipeline exposing (optional, required)
import Loading
import Set exposing (Set)
import Time exposing (Month)
import Url exposing (Url)


type alias Model =
    { navKey : Maybe Nav.Key
    , page : Page
    , navState : Maybe Navbar.State
    , loading : Loading.LoadingState
    , saving : Loading.LoadingState
    , problems : List Problem
    , loginForm : LoginForm
    , registerForm : RegisterForm
    , survey : Survey
    , surveyForm : SurveyForm
    , session : Session
    , apiActionResponse : ApiActionResponse
    , loggedInUser : User
    , timeZone : Time.Zone
    , time : Time.Posix
    , surveysList : List Survey
    , sponsorableUsers : List SponsorableUser
    , preReleaseUsers : List PreReleaseUser
    }


type Page
    = Home
    | Login
    | Logout
    | Register (Maybe String) (Maybe String)
    | Surveys Int
    | SurveysEdit Int
    | SurveysList
    | NotFound


type alias Session =
    { loginExpire : String
    , loginToken : String
    }


type alias ApiActionResponse =
    { status : Int
    , resourceId : Int
    , resourceIds : List Int
    }


type alias User =
    { id : Int
    , name : String
    , email : String
    , permissions : Int
    }


type alias Survey =
    { id : Int
    , user_id : Int
    , name : String
    , github_id : String
    , priorities : String
    , issues : String
    , comms_frequency : String
    , pre_release : Bool
    , privacy : String
    }


type alias SurveyForm =
    { id : Int
    , user_id : Int
    , name : String
    , sponsored_users : Set Int
    , github_id : String
    , priorities : String
    , issues : String
    , comms_frequency : String
    , pre_release : Bool
    , privacy : String
    }


type alias SurveySponsor =
    { id : Int
    , survey_id : Int
    , user_id : Int
    }


type alias SponsorableUser =
    { id : Int
    , name : String
    , github_id : String
    }


type alias PreReleaseUser =
    { id : Int
    , name : String
    , email : String
    }


type alias Configuration =
    { authorizationEndpoint : Url
    , clientId : String
    , scope : List String
    }


type alias LoginForm =
    { email : String
    , password : String
    }


type alias RegisterForm =
    { email : String
    , password : String
    , password_confirm : String
    , verification : String
    }


type ValidatedField
    = Email
    | Password
    | ConfirmPassword
    | Name
    | GitHubId


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type Msg
    = ChangedUrl Url
    | ClickedLink UrlRequest
    | NavMsg Navbar.State
    | SubmittedLoginForm
    | SubmittedRegisterForm
    | SubmittedSurveyForm
    | EnteredLoginEmail String
    | EnteredLoginPassword String
    | EnteredRegisterEmail String
    | EnteredRegisterPassword String
    | EnteredRegisterConfirmPassword String
    | EnteredSurveyName String
    | EnteredSurveyGitHubUserId String
    | EnteredSurveyPriorities String
    | EnteredSurveyIssues String
    | EnteredSurveyCommsFrequency String
    | EnteredSurveyPreRelease Bool
    | EnteredSurveyPrivacy String
    | CompletedLogin (Result Http.Error Session)
    | GotRegisterJson (Result Http.Error ApiActionResponse)
    | LoadedUser (Result Http.Error User)
    | LoadedSurvey (Result Http.Error Survey)
    | GotUpdateSurveyJson (Result Http.Error ApiActionResponse)
    | GotUpdateSurveyWithSponsorStateJson (Result Http.Error ApiActionResponse)
    | LoadedSurveys (Result Http.Error (List Survey))
    | LoadedSponsorsForSurvey (Result Http.Error (List SurveySponsor))
    | LoadedSponsorableUsers (Result Http.Error (List SponsorableUser))
    | LoadedPreReleaseUsers (Result Http.Error (List PreReleaseUser))
    | EnteredUserToAddSponsor Int Bool
    | AdjustTimeZone Time.Zone
    | TimeTick Time.Posix



-- FORMATTERS AND LOCALS


tgsLocale : Locale
tgsLocale =
    Locale (Exact 4) "" "." "−" "" "" "" "" ""


toIntMonth : Month -> Int
toIntMonth month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12


formatDate : Model -> Time.Posix -> String
formatDate model date =
    let
        valid =
            Time.posixToMillis date > 0

        year =
            String.fromInt (Time.toYear model.timeZone date)

        month =
            String.padLeft 2 '0' (String.fromInt (toIntMonth (Time.toMonth model.timeZone date)))

        day =
            String.padLeft 2 '0' (String.fromInt (Time.toDay model.timeZone date))
    in
    if valid then
        year ++ "-" ++ month ++ "-" ++ day

    else
        "Unknown"


isNot : Int -> Int -> Bool
isNot a b =
    if a == b then
        False

    else
        True


toIsoString : Model -> Time.Posix -> String
toIsoString model date =
    let
        year =
            String.fromInt (Time.toYear model.timeZone date)

        month =
            String.padLeft 2 '0' (String.fromInt (toIntMonth (Time.toMonth model.timeZone date)))

        day =
            String.padLeft 2 '0' (String.fromInt (Time.toDay model.timeZone date))
    in
    year ++ "-" ++ month ++ "-" ++ day



-- INDEXERS


indexUser : User -> ( String, User )
indexUser user =
    ( String.fromInt user.id, user )



-- EMPTIES


emptyUser : User
emptyUser =
    { id = 0
    , name = ""
    , email = ""
    , permissions = 0
    }


emptySession : Session
emptySession =
    { loginExpire = "", loginToken = "" }


emptySurvey : Survey
emptySurvey =
    { id = 0
    , user_id = 0
    , name = ""
    , github_id = ""
    , priorities = ""
    , issues = ""
    , comms_frequency = ""
    , pre_release = False
    , privacy = ""
    }


emptySurveyForm : SurveyForm
emptySurveyForm =
    { id = 0
    , user_id = 0
    , name = ""
    , sponsored_users = Set.empty
    , github_id = ""
    , priorities = ""
    , issues = ""
    , comms_frequency = ""
    , pre_release = False
    , privacy = ""
    }



-- DECODERS


resourceIdsDecoder : Decoder (List Int)
resourceIdsDecoder =
    list int


apiActionDecoder : Decoder ApiActionResponse
apiActionDecoder =
    Decode.succeed ApiActionResponse
        |> required "status" int
        |> optional "resourceId" int 0
        |> optional "resourceIds" resourceIdsDecoder []


userDecoder : Decoder User
userDecoder =
    Decode.succeed User
        |> required "ID" int
        |> required "Name" string
        |> optional "Email" string ""
        |> optional "Permissions" int 0


surveyDecoder : Decoder Survey
surveyDecoder =
    Decode.succeed Survey
        |> required "ID" int
        |> optional "UserId" int 0
        |> required "Name" string
        |> required "GitHubId" string
        |> required "Priorities" string
        |> required "Issues" string
        |> required "CommsFrequency" string
        |> optional "PreRelease" bool False
        |> required "Privacy" string


surveySponsorDecoder : Decoder SurveySponsor
surveySponsorDecoder =
    Decode.succeed SurveySponsor
        |> required "ID" int
        |> optional "SurveyId" int 0
        |> optional "UserId" int 0


sponsorableUserDecoder : Decoder SponsorableUser
sponsorableUserDecoder =
    Decode.succeed SponsorableUser
        |> required "ID" int
        |> optional "Name" string ""
        |> optional "GitHubId" string ""


preReleaseUserDecoder : Decoder PreReleaseUser
preReleaseUserDecoder =
    Decode.succeed PreReleaseUser
        |> required "ID" int
        |> optional "Name" string ""
        |> optional "Email" string ""


posixTime : Decode.Decoder Time.Posix
posixTime =
    Decode.int
        |> Decode.andThen
            (\ms -> Decode.succeed <| Time.millisToPosix ms)



-- AUTH HEADER


authHeader : String -> Http.Header
authHeader token =
    Http.header "authorization" ("Bearer " ++ token)
