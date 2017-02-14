module ParentChildUpdate
    exposing
        ( updateChildApp
        , updateChildParent
        )

{-| Parent/Child message processing helper functions for stateless components

@docs  updateChildApp, updateChildParent

-}

import Tuple exposing (first)


type alias AppUpdate appMsg appModel =
    appMsg -> appModel -> ( appModel, Cmd appMsg )


type alias ParentUpdate parentMsg parentModel grandParentMsg =
    parentMsg -> parentModel -> ( ( parentModel, Cmd parentMsg ), List grandParentMsg )


type alias DoParentMsgs parentModel parentMsg childMsg grandParentMsg =
    parentModel -> List parentMsg -> (childMsg -> parentMsg) -> Cmd childMsg -> ( ( parentModel, Cmd parentMsg ), List grandParentMsg )


type alias ChildUpdate childMsg childModel parentMsg =
    childMsg -> childModel -> ( ( childModel, Cmd childMsg ), List parentMsg )


type alias ChildModelAccessor parentModel childModel =
    parentModel -> childModel


type alias ChildTagger childMsg parentMsg =
    childMsg -> parentMsg


type alias ReplaceChildModel parentModel childModel =
    parentModel -> childModel -> parentModel



-- helpers


doAppMsgs : AppUpdate appMsg appModel -> DoParentMsgs appModel appMsg childMsg grandParentMsg
doAppMsgs appUpdate appModel appMsgs childTagger childCmd =
    let
        doUpdate appMsg appModel appCmds =
            let
                ( newappModel, appCmd ) =
                    appUpdate appMsg appModel
            in
                ( newappModel, appCmd :: appCmds )

        ( finalModel, appCmds ) =
            List.foldl (\msg ( model, cmds ) -> doUpdate msg model cmds) ( appModel, [] ) appMsgs
    in
        ( finalModel ! (Cmd.map childTagger childCmd :: appCmds), [] )


doParentMsgs : ParentUpdate parentMsg parentModel grandParentMsg -> DoParentMsgs parentModel parentMsg childMsg grandParentMsg
doParentMsgs parentUpdate parentModel parentMsgs childTagger childCmd =
    let
        doUpdate parentMsg parentModel parentCmds grandParentMsgs =
            let
                ( ( newParentModel, parentCmd ), additionalGrandParentMsgs ) =
                    parentUpdate parentMsg parentModel
            in
                ( ( newParentModel, parentCmd :: parentCmds ), List.append additionalGrandParentMsgs grandParentMsgs )

        ( ( finalModel, parentCmds ), grandParentMsgs ) =
            List.foldl (\msg ( ( model, cmds ), parentMsgs ) -> doUpdate msg model cmds parentMsgs) ( ( parentModel, [] ), [] ) parentMsgs
    in
        ( finalModel ! (Cmd.map childTagger childCmd :: parentCmds), grandParentMsgs )


updateChildParentCommon : DoParentMsgs parentModel parentMsg childMsg grandParentMsg -> ChildUpdate childMsg childModel parentMsg -> ChildModelAccessor parentModel childModel -> ChildTagger childMsg parentMsg -> ReplaceChildModel parentModel childModel -> childMsg -> parentModel -> ( ( parentModel, Cmd parentMsg ), List grandParentMsg )
updateChildParentCommon doParentMsgs childUpdate childModelAccessor childTagger replaceChildModel childMsg parentModel =
    let
        ( ( childModel, childCmd ), parentMsgs ) =
            childUpdate childMsg (childModelAccessor parentModel)
    in
        doParentMsgs (replaceChildModel parentModel childModel) parentMsgs childTagger childCmd



-- API


{-|
    Helper function to call non-App Child's update with a message and then call the Parent's update with the messages returned by the Child.
-}
updateChildParent : ChildUpdate childMsg childModel parentMsg -> ParentUpdate parentMsg parentModel grandParentMsg -> ChildModelAccessor parentModel childModel -> ChildTagger childMsg parentMsg -> ReplaceChildModel parentModel childModel -> childMsg -> parentModel -> ( ( parentModel, Cmd parentMsg ), List grandParentMsg )
updateChildParent childUpdate parentUpdate childModelAccessor childTagger replaceChildModel =
    updateChildParentCommon (doParentMsgs parentUpdate) childUpdate childModelAccessor childTagger replaceChildModel


{-|
    Helper function to call App Child's update with a message and then call the App's update with the messages returned by the Child.
-}
updateChildApp : ChildUpdate childMsg childModel appMsg -> AppUpdate appMsg appModel -> ChildModelAccessor appModel childModel -> ChildTagger childMsg appMsg -> ReplaceChildModel appModel childModel -> childMsg -> appModel -> ( appModel, Cmd appMsg )
updateChildApp childUpdate appUpdate childModelAccessor childTagger replaceChildModel childMsg appModel =
    first <| updateChildParentCommon (doAppMsgs appUpdate) childUpdate childModelAccessor childTagger replaceChildModel childMsg appModel
