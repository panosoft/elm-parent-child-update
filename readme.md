# Helper functions for Stateless Components in Elm

> Micro-library to reduce boilerplate code for implementing Parent/Child communication in stateless components.

## Aren't components bad in Elm

The prevailing belief that `components are bad and functions are good` is mainly because of semantics. When people use the word `component`, many times it conjurs up Objects with internal state. So, the Elm community has avoided this term and instead talks about factoring out functions.

Factoring out functions is fine, but only to a point. When communication between Parent and Child components is warranted, then a simple communication mechanism is desirable.

This library provides a mechanism for such communication.


## Elm Programs are State Machines

Messages passed to `update` are Edges of a State Machine. If a message mutates the Model, then the edge goes from the current state into a new state. If a messages does NOT mutate the Model, then the edge loops back on the current state.

As programs grow in complexity, it's easy to just add messages to the current module and to add fields to the Model. But this is just out of convenience not necessarily good coding practices. When a module contains 2 or more State Machines, it should be refactored.

Generally speaking, a `Stateless Component` should be a single State Machine to follow the `Single Responsibilty Principle`.

To properly decompose an Elm program, one should factor out the messages that correspond to a single State Machine and any data from the model that is mutated by those messages into a Child Component. This component is a `Stateless Component` and will have its model passed to it by its Parent.


## When to Use

Every Elm program can be thought of as a `Stateless Component`. The Elm Runtime passes in the program's state to `update` for potential mutation. In this library, the top-level is called the `App`. For simple applications, there is no need for additional components. As an App becomes more complex, then additional State Machines may be introduced. When this occurs, then refactoring should be considered.

This need is common in `Server Applications`. For example, imagine a Server Program that contains multiple, independent `Services`. Each `Service` should define its own `Model` and have its own `messages` (which means it must have its own `update` function). Each Service should also be a single State Machine. In this scenario, each Service (Child) needs to communicate back to the Server (App) via Server Messages.

***Anytime a Child Component needs to return messages to its Parent, then this library is useful***


## Parent/Child Communication

If the App contains components, then those components are considered `Child` components of the App. Any component can have `Child` components and are considered `Parent` components to their children.

All components rely on their Parent to pass in state and messages into their `update` function. In the case of the App, the Elm Runtime can be thought of as the App's Parent.

At the App level, `update` returns a new `Model` and a `Cmd`. But at lower-levels, a Child component need a mechanism for communicating with their Parent. Therefore, there are 2 different signatures for `update`:

```elm
-- App's update
update : Msg -> Model -> ( Model, Cmd Msg )

-- Child component's update
update : Config msg -> Msg -> Model -> ( ( Model, Cmd Msg ), List msg)
```
For Child components there is an optional configuration parameter. This configuration contains the Parent's message taggers for creating messages that will be sent back to the Parent via the additional return parameter, which is a `List` of Parent messages. (This same configuration parameter can also be passed to the Child's `subscriptions` function.)

When a Parent gets a message destined for one of its children, it will call the Child's `update` function, which will return a new Child Model, a Command to be run and a List of Parent messages.

The Parent will then take these messages and recursively call its `update` function mutating its model through each iteration.

This code is complex and quickly becomes boilerplate. This library hopes to greatly reduce both.


## API

Imagine the following scenario:

<p align="center"><img src="images/Parent Child Components.png"></p>

Here the `App` has a `Child` component which in turn has a child labeled `Grandchild`.

Since the App's `update` function has a different signature than the Child or Grandchild's `update`, there needs to be 2 different API functions.


### App Children
The first is for the App children:

```elm
updateChildApp : ChildUpdate childMsg childModel appMsg -> AppUpdate appMsg appModel -> ChildModelAccessor appModel childModel -> ChildTagger childMsg appMsg -> ReplaceChildModel appModel childModel -> childMsg -> appModel -> ( appModel, Cmd appMsg )
updateChildApp childUpdate appUpdate childModelAccessor childTagger replaceChildModel childMsg appModel
```

In our example scenario, this function updates `Child` THEN `App`, hence the name `updateChildApp`. In detail, the `Child`'s `update` function is called. Then the `App`'s model is mutated to include the new `Child` model. And finally, the `App`'s update function is called recursively with each message that was returned in the `List` of messages returned from the `Child`'s update. Since the `App`'s `update` mutates the model, that mutated model is passed to subsequent calls to `update`.


### Non-App Children
The second API function is for non-App children:

```elm
updateChildParent : ChildUpdate childMsg childModel parentMsg -> ParentUpdate parentMsg parentModel grandParentMsg -> ChildModelAccessor parentModel childModel -> ChildTagger childMsg parentMsg -> ReplaceChildModel parentModel childModel -> childMsg -> parentModel -> ( ( parentModel, Cmd parentMsg ), List grandParentMsg )
updateChildParent childUpdate parentUpdate childModelAccessor childTagger replaceChildModel childMsg appModel
```

In our example scenario, this function updates the `Grandchild` THEN the `Child`, hence the name `updateChildParent`.


## Usage

### Steps to implement a Child Component

To implement a Child Component using this library, there are 7 modifications to an App (or Parent Component) that must be made:

	1. Import the ParentChildUpdate module from this library
	2. Import Child module
	3. Add Child Model to App (or Parent) Model
	4. Add Child Message to App (or Parent) Msg type
	5. Handle Child Message in update function
	6. Create a function using this libary to update Child and App (or Parent)
	7. Handle any Child subscriptions

The easiest way to understand the API is to see an example of how it's used.

### App code
Here's the salient code in the App:

```elm
module App exposing (..)

import ParentChildUpdate exposing (..)
import Child exposing (..)


type alias Model =
    { childModel : Child.Model Msg
    }


init : ( Model, Cmd Msg )
init =
	{ childModel = Child.initModel } ! []


type Msg
    = Nop
    | AppMsg1
    | AppMsg2
    | ChildModule Child.Msg

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Nop ->
            model ! []
        AppMsg1 ->
            model ! []
        AppMsg2 ->
            model ! []
		ChildModule childMsg ->
			updateChild childMsg

childConfig : Child.Config
childConfig =
	{ onEvent1 = AppMsg1 }


updateChild : Child.Msg -> Model -> ( Model, Cmd Msg )
updateChild =
    ParentChildUpdate.updateChildApp (Child.update childConfig) update .childModel ChildModule (\model childModel -> { model | childModel = childModel })


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map ChildModule <| (Child.subscriptions childConfig) model.childModel

```
N.B. that `updateChild` uses the API function `updateChildApp`. That's because we're at the App level and the App and its children have different `update` function signatures.

Here, the App's model contains the Child's model.

The App tags (or wraps) messages destined for the Child component with the function `ChildModule`.

The lambda function mutates the App's model to replace the Child's model.

The Child's configuration is passed to its `subscriptions` function.


### Child code
Here's the salient code in the Child:

```elm
module Child exposing (..)

import ParentChildUpdate exposing (..)
import Grandchild exposing (..)


type alias Model =
    { grandchildModel : Grandchild.Model Msg
    }


initModel : Model
initModel =
	{ grandchildModel = Grandchild.initModel }


type Msg
    = Nop
    | ChildMsg1
    | ChildMsg2
    | GrandchildModule Grandchild.Msg


update : Config msg -> Msg -> Model -> ( ( Model, Cmd Msg ), List msg )
update config msg model =
    case msg of
        Nop ->
            (model ! [], [])
        ChildMsg1 ->
            (model ! [], [])
        ChildMsg2 ->
            (model ! [], [])
		GrandchildModule grandchildMsg ->
			updateGrandChild grandchildMsg


grandchildConfig : Grandchild.Config
grandchildConfig =
	{ onEvent1 = ChildMsg1, onEvent2 = ChildMsg2 }


updateGrandchild : Grandchild.Msg -> Model -> ( ( Model, Cmd Msg ), List msg )
updateGrandchild =
    ParentChildUpdate.updateChildParent (Grandchild.update grandchildConfig) update .grandchildModel GrandchildModule (\model grandchildModel -> { model | grandchildModel = grandchildModel })


subscriptions : Config msg -> Model -> Sub Msg
subscriptions config model =
    Sub.map GrandchildModule <| (Grandchild.subscriptions grandchildConfig) model.grandchildModel

```
N.B. that `updateGrandchild` uses the API function `updateChildParent`. That's because we're NOT at the App level and we and our children have similar `update` function signatures.

Here, the Child's model contains the Grandchild's model.

The Child tags messages destined for the Grandchild component with the function `GrandchildModule`.

The lambda function mutates the Child's model to replace the Grandchild's model.

The Child's configuration is passed to its `subscriptions` function.

**The only difference between the `App` code and the `Child` code above is which API function from this library is used.**

### Additional Descendants
The `Grandchild` component can also have children and so on. The code for all subsequent descendants is identical to the code in the `Child` above since the only special case is at the top-level, i.e. the App level.
