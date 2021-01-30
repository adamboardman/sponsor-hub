port module Ports exposing (onStoreExpireChange, onStoreTokenChange, storeExpire, storeToken)


port onStoreTokenChange : (String -> msg) -> Sub msg


port onStoreExpireChange : (String -> msg) -> Sub msg


port storeToken : Maybe String -> Cmd msg


port storeExpire : Maybe String -> Cmd msg
