module Main exposing (main)

import Bootstrap.Grid as Grid
import Bootstrap.Navbar as Navbar
import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Html exposing (Html, div, h1, text)
import Html.Attributes exposing (href)
import Http exposing (Error(..), emptyBody)
import Loading exposing (LoadingState(..))
import Login exposing (loggedIn, login, loginUpdateForm, loginValidate, pageLogin)
import Ports exposing (storeExpire, storeToken)
import Register exposing (pageRegister, register, registerUpdateForm, registerValidate)
import Survey exposing (pageSurvey, survey, surveyUpdateForm, surveyValidate)
import Task
import Time
import Types exposing (..)
import Url exposing (Url)
import Url.Parser as UrlParser exposing ((</>), (<?>), Parser, s, top)
import Url.Parser.Query as Query



-- TYPES


type alias Flags =
    { token : Maybe String
    , expire : Maybe String
    }



-- MAIN


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        ( navState, navCmd ) =
            Navbar.initialState NavMsg

        ( model, urlCmd ) =
            urlUpdate url
                { navKey = Just key
                , navState = Just navState
                , page = Home
                , loading = Loading.Off
                , saving = Loading.Off
                , problems = []
                , loginForm = { email = "", password = "" }
                , registerForm = { email = "", password = "", password_confirm = "", verification = "" }
                , session = { loginExpire = Maybe.withDefault "" flags.expire, loginToken = Maybe.withDefault "" flags.token }
                , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                , loggedInUser = emptyUser
                , surveyForm = emptySurveyForm
                , timeZone = Time.utc
                , time = Time.millisToPosix 0
                }
    in
    ( model
    , Cmd.batch
        [ urlCmd
        , navCmd
        , case flags.token of
            Just token ->
                loadUser token 0

            Nothing ->
                Cmd.none
        , Task.perform AdjustTimeZone Time.here
        , Task.perform TimeTick Time.now
        ]
    )


view : Model -> Document Msg
view model =
    { title = "Github Sponsors Feedback"
    , body =
        [ div []
            [ menu model
            , mainContent model
            ]
        ]
    }


menu : Model -> Html Msg
menu model =
    case model.navState of
        Just navState ->
            Navbar.config NavMsg
                |> Navbar.withAnimation
                |> Navbar.container
                |> Navbar.brand [ href (urlForPage Home) ] [ text "Sponsor-Hub" ]
                |> Navbar.items
                    [ if loggedIn model then
                        Navbar.itemLink [ href (urlForPage Logout) ] [ text "Logout" ]

                      else
                        Navbar.itemLink [ href (urlForPage Login) ] [ text "Login" ]
                    ]
                |> Navbar.view navState

        Nothing ->
            div [] []


mainContent : Model -> Html Msg
mainContent model =
    Grid.container [] <|
        case model.page of
            Home ->
                if loggedIn model then
                    pageSurvey model

                else
                    pageLogin model

            Login ->
                pageLogin model

            Logout ->
                pageLogout model

            Register email _ ->
                pageRegister model email

            Survey ->
                pageSurvey model

            NotFound ->
                pageNotFound


pageLogout : Model -> List (Html Msg)
pageLogout model =
    [ text "Logged Out"
    ]


pageNotFound : List (Html Msg)
pageNotFound =
    [ h1 [] [ text "Not found" ]
    , text "Sorry couldn't find that page"
    ]



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedLink urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( { model
                        | problems = []
                        , loginForm = { email = "", password = "" }
                        , registerForm = { email = "", password = "", password_confirm = "", verification = "" }
                        , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                        , session =
                            case Maybe.withDefault "" url.fragment of
                                "logout" ->
                                    emptySession

                                _ ->
                                    model.session
                      }
                    , case model.navKey of
                        Just navKey ->
                            case Maybe.withDefault "" url.fragment of
                                "logout" ->
                                    Cmd.batch
                                        [ Nav.pushUrl navKey (urlForPage Home)
                                        , storeToken Nothing
                                        , storeExpire Nothing
                                        ]

                                _ ->
                                    Nav.pushUrl navKey (Url.toString url)

                        Nothing ->
                            Cmd.none
                    )

                Browser.External href ->
                    ( model, Nav.load href )

        ChangedUrl url ->
            urlUpdate url model

        NavMsg state ->
            ( { model | navState = Just state }, Cmd.none )

        SubmittedLoginForm ->
            case loginValidate model.loginForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , login validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
                    , Cmd.none
                    )

        SubmittedRegisterForm ->
            case registerValidate model.registerForm of
                Ok validForm ->
                    ( { model | problems = [], loading = Loading.On }
                    , register validForm
                    )

                Err problems ->
                    ( { model | problems = problems, loading = Loading.Off }
                    , Cmd.none
                    )

        SubmittedSurveyForm ->
            case surveyValidate model.surveyForm of
                Ok validForm ->
                    ( { model | problems = [], saving = Loading.On }
                    , survey model.session.loginToken validForm
                    )

                Err problems ->
                    ( { model | problems = problems, saving = Loading.Off }
                    , Cmd.none
                    )

        EnteredLoginEmail email ->
            loginUpdateForm (\form -> { form | email = email }) model

        EnteredRegisterEmail email ->
            registerUpdateForm (\form -> { form | email = email }) model

        EnteredLoginPassword password ->
            loginUpdateForm (\form -> { form | password = password }) model

        EnteredRegisterPassword password ->
            registerUpdateForm (\form -> { form | password = password }) model

        EnteredRegisterConfirmPassword passwordConfirm ->
            registerUpdateForm (\form -> { form | password_confirm = passwordConfirm }) model

        EnteredSurveyName name ->
            surveyUpdateForm (\form -> { form | name = name }) model

        EnteredSurveyGitHubUserId gitHubId ->
            surveyUpdateForm (\form -> { form | github_id = gitHubId }) model

        EnteredSurveyPriorities priorities ->
            surveyUpdateForm (\form -> { form | priorities = priorities }) model

        EnteredSurveyCommsFrequency commsFrequency ->
            surveyUpdateForm (\form -> { form | comms_frequency = commsFrequency }) model

        EnteredSurveyPrivacy privacy ->
            surveyUpdateForm (\form -> { form | privacy = privacy }) model

        CompletedLogin (Err error) ->
            let
                serverErrors =
                    decodeErrors error
                        |> List.map ServerError
            in
            ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off }
            , Cmd.batch
                [ storeToken Nothing
                , storeExpire Nothing
                ]
            )

        CompletedLogin (Ok res) ->
            ( { model | session = res, loading = Loading.Off }
            , Cmd.batch
                [ loadUser res.loginToken 0
                , storeToken (Just res.loginToken)
                , storeExpire (Just res.loginExpire)
                , case model.navKey of
                    Just navKey ->
                        Nav.pushUrl navKey (urlForPage Home)

                    Nothing ->
                        Cmd.none
                ]
            )

        LoadedUser (Err error) ->
            ( { model | loggedInUser = emptyUser, loading = Loading.Off, session = sessionGivenAuthError error model }
            , Cmd.none
            )

        LoadedUser (Ok res) ->
            ( { model | loggedInUser = res, loading = Loading.Off }
            , Cmd.none
            )

        LoadedSurvey (Err error) ->
            ( { model | surveyForm = emptySurveyForm, loading = Loading.Off, session = sessionGivenAuthError error model }
            , Cmd.none
            )

        LoadedSurvey (Ok res) ->
            ( { model | surveyForm = res, loading = Loading.Off }
            , Cmd.none
            )

        GotRegisterJson result ->
            case result of
                Ok res ->
                    ( { model | apiActionResponse = res, loading = Loading.Off }, Cmd.none )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, loading = Loading.Off, session = sessionGivenAuthError error model }
                    , Cmd.none
                    )

        GotUpdateSurveyJson result ->
            case result of
                Ok res ->
                    let
                        transform =
                            \form -> { form | id = res.resourceId }
                    in
                    ( { model | apiActionResponse = res, saving = Loading.Off, surveyForm = transform model.surveyForm }, Cmd.none )

                Err error ->
                    let
                        serverErrors =
                            decodeErrors error
                                |> List.map ServerError
                    in
                    ( { model | problems = List.append model.problems serverErrors, saving = Loading.Off, session = sessionGivenAuthError error model }
                    , Cmd.none
                    )

        AdjustTimeZone zone ->
            ( { model | timeZone = zone }, Cmd.none )

        TimeTick posix ->
            ( { model | time = posix }, Cmd.none )


sessionGivenAuthError : Http.Error -> Model -> Session
sessionGivenAuthError error model =
    if error == BadStatus 401 then
        emptySession

    else
        model.session


decodeErrors : Http.Error -> List String
decodeErrors error =
    case error of
        Timeout ->
            [ "Timeout exceeded" ]

        NetworkError ->
            [ "Network error" ]

        BadBody body ->
            [ body ]

        BadUrl url ->
            [ "Malformed url: " ++ url ]

        BadStatus 401 ->
            [ "Invalid Username or Password" ]

        err ->
            [ "Server error" ]


fromPair : ( String, List String ) -> List String
fromPair ( field, errors ) =
    List.map (\error -> field ++ " " ++ error) errors


urlForPage : Page -> String
urlForPage page =
    case page of
        Survey ->
            "#"

        Home ->
            "#"

        Login ->
            "#login"

        Logout ->
            "#logout"

        Register _ _ ->
            "#register"

        NotFound ->
            "#"


urlUpdate : Url -> Model -> ( Model, Cmd Msg )
urlUpdate url model =
    case decode url of
        Nothing ->
            ( { model | page = NotFound }, Cmd.none )

        Just page ->
            ( case page of
                Register email verification ->
                    { model
                        | page = page
                        , registerForm =
                            { email = Maybe.withDefault "" email
                            , password = ""
                            , password_confirm = ""
                            , verification = Maybe.withDefault "" verification
                            }
                    }

                Home ->
                    { model | loading = On }

                _ ->
                    { model | page = page }
            , case page of
                Home ->
                    Cmd.batch [ loadSurvey model.session.loginToken ]

                Login ->
                    Cmd.none

                Logout ->
                    Cmd.none

                Register _ _ ->
                    Cmd.none

                NotFound ->
                    Cmd.none

                Survey ->
                    loadSurvey model.session.loginToken
            )


decode : Url -> Maybe Page
decode url =
    { url | path = Maybe.withDefault "" url.fragment, fragment = Nothing }
        |> UrlParser.parse routeParser


routeParser : Parser (Page -> a) a
routeParser =
    UrlParser.oneOf
        [ UrlParser.map Home top
        , UrlParser.map Login (s "login")
        , UrlParser.map Logout (s "logout")
        , UrlParser.map Register (s "register" <?> Query.string "email" <?> Query.string "verification")
        ]



-- HTTP


loadUser : String -> Int -> Cmd Msg
loadUser token userId =
    Http.request
        { method = "GET"
        , url = "/api/users/" ++ String.fromInt userId
        , expect = Http.expectJson LoadedUser userDecoder
        , headers = [ authHeader token ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


loadSurvey : String -> Cmd Msg
loadSurvey token =
    Http.request
        { method = "GET"
        , url = "api/surveys/0"
        , expect = Http.expectJson LoadedSurvey surveyDecoder
        , headers = [ authHeader token ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model.navState of
            Just navState ->
                Navbar.subscriptions navState NavMsg

            Nothing ->
                Sub.none
        , Time.every (30 * 1000) TimeTick
        ]