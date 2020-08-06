module NoMissingTemplateValueTest exposing (all)

import Expect exposing (Expectation)
import NoMissingTemplateValue exposing (rule)
import Review.Test exposing (ExpectedError, ReviewResult)
import Test exposing (Test, concat, describe, test)


all : Test
all =
    concat
        [ identifiesPlaceholderSyntax
        , namePaddingIsIgnored
        , spacesInNamesIsNotIgnored
        , multiplePlaceholdersAndValues
        ]


identifiesPlaceholderSyntax : Test
identifiesPlaceholderSyntax =
    describe "Identifies placeholder syntax"
        [ passes "" []
        , passes "foo" []
        , passes "${}" [ ( "", "" ) ]
        , passes "${${}" [ ( "${", "" ) ]
        ]


namePaddingIsIgnored : Test
namePaddingIsIgnored =
    describe "Name padding is ignored"
        [ passes "${foo}" [ ( "foo", "bar" ) ]
        , passes "${ foo}" [ ( "foo", "bar" ) ]
        , passes "${foo }" [ ( "foo", "bar" ) ]
        , passes "${   foo   }" [ ( "foo", "bar" ) ]
        ]


spacesInNamesIsNotIgnored : Test
spacesInNamesIsNotIgnored =
    describe "Spaces in Names is not ignored"
        [ passes "${foo}" [ ( "foo", "bar" ) ]
        , fails "${f oo}"
            [ ( "foo", "bar" ) ]
            [ placeholderWithoutValueError "${f oo}"
            , unusedKeyError "foo"
            ]
        , passes "${f oo}" [ ( "f oo", "bar" ) ]
        , fails "${f oo}"
            [ ( "foo", "bar" ) ]
            [ placeholderWithoutValueError "${foo}"
            , unusedKeyError "foo"
            ]
        ]


multiplePlaceholdersAndValues : Test
multiplePlaceholdersAndValues =
    describe "Multiple placeholders and values"
        [ passes "${}{}" [ ( "", "foo" ) ]
        , passes "${x} ${y} ${x}" [ ( "x", "foo" ), ( "y", "bar" ) ]
        , fails "${x} ${y}"
            [ ( "x", "foo" ) ]
            [ placeholderWithoutValueError "y" ]
        , fails "${x}"
            [ ( "x", "foo" ), ( "y", "bar" ) ]
            [ unusedKeyError "y" ]
        ]


passes : String -> List ( String, String ) -> Test
passes template toInject =
    unitTest template
        template
        toInject
        Review.Test.expectNoErrors


fails : String -> List ( String, String ) -> List ExpectedError -> Test
fails template toInject errors =
    unitTest template
        template
        toInject
        (Review.Test.expectErrors errors)


unitTest : String -> String -> List ( String, String ) -> (ReviewResult -> Expectation) -> Test
unitTest desc template toInject expect =
    let
        toInjectStr : String
        toInjectStr =
            "[ "
                ++ (List.map (\( key, value ) -> "( " ++ key ++ ", " ++ value ++ ")") toInject
                        |> String.join ", "
                   )
                ++ " ]"
    in
    describe desc
        [ test "Normal application" <|
            \_ ->
                ("""module Foo exposing (bar)
import String.Template
bar = String.Template.inject \"\"\"""" ++ template ++ "\"\"\"  " ++ toInjectStr)
                    |> Review.Test.run rule
                    |> expect
        , test "Normal application with `exposing` import" <|
            \_ ->
                ("""module Foo exposing (bar)
import String.Template exposing (inject)
bar = inject \"\"\"""" ++ template ++ "\"\"\"  " ++ toInjectStr)
                    |> Review.Test.run rule
                    |> expect
        , test "Normal application with `as` import" <|
            \_ ->
                ("""module Foo exposing (bar)
import String.Template as T
bar = T.inject \"\"\"""" ++ template ++ "\"\"\"  " ++ toInjectStr)
                    |> Review.Test.run rule
                    |> expect
        , test "Right pipe appilcation" <|
            \_ ->
                ("""module Foo exposing (bar)
import String.Template
bar = \"\"\"""" ++ template ++ "\"\"\" |> String.Template.inject " ++ toInjectStr)
                    |> Review.Test.run rule
                    |> expect
        , test "Left pipe application" <|
            \_ ->
                ("""module Foo exposing (bar)
import String.Template
bar = String.Template.inject """ ++ toInjectStr ++ " <| \"\"\"" ++ template ++ "\"\"\"")
                    |> Review.Test.run rule
                    |> expect
        ]


duplicateKeysError : String -> ExpectedError
duplicateKeysError under =
    Review.Test.error
        { message = "Duplicate keys."
        , details = [ "You already have a key with the same name. Rename this key to something eles" ]
        , under = under
        }


unusedKeyError : String -> ExpectedError
unusedKeyError under =
    Review.Test.error
        { message = "Unused key."
        , details = [ "This keys is not being used anywhere in the template, maybe you meant to use it but misspelled the key or placeholder name?" ]
        , under = under
        }


placeholderWithoutValueError : String -> ExpectedError
placeholderWithoutValueError under =
    Review.Test.error
        { message = "Placeholder has no value"
        , details = [ "This placeholder has no value associated, i.e. there's no key with the same name as the placeholder. Maybe you meant to asign it a value but misspelled the key or placeholder name?" ]
        , under = under
        }
