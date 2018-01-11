import Html exposing (Html, button, div, text, ul, li)
import Html.Events exposing (onClick)
import List.Zipper exposing (Zipper, singleton, toList)
import Svg exposing (Svg, svg, g, title, circle, line, rect, text_)
import Svg.Attributes exposing (version, viewBox,
    transform,
    stroke, strokeWidth,
    fontSize,
    color, fill,
    width, height,
    alignmentBaseline, fontFamily, textAnchor,
    cx, cy, r,
    x1, y1, x2, y2,
    x, y, rx, ry)

main = Html.program {
    init = init,
    update = update,
    subscriptions = subscriptions,
    view = view }

type Cat = Id String
         | Prim String String
         | Comp Cat Cat

sourceType : Cat -> String
sourceType cat = case cat of
    Id ty -> ty
    Prim ty _ -> ty
    Comp f _ -> sourceType f

targetType : Cat -> String
targetType cat = case cat of
    Id ty -> ty
    Prim _ ty -> ty
    Comp _ g -> targetType g

type Menu = CatMenu Cat

type alias State = (Cat, Maybe Menu)

type Action = MenuFor Cat

init : (State, Cmd Action)
init = ((Comp (Prim "lo'i bloti" "lo'i mlatu") (Comp (Id "lo'i mlatu") (Prim "lo'i mlatu" "lo'i se mlatu")), Nothing), Cmd.none)

update : Action -> State -> (State, Cmd Action)
update (MenuFor cat) (zd, _) = ((zd, Just (CatMenu cat)), Cmd.none)

subscriptions : State -> Sub Action
subscriptions s = Sub.none

unorderedList : List (Html a) -> Html a
unorderedList xs = ul [] (List.map (\x -> li [] [x]) xs)

viewMenu : Menu -> Html Action
viewMenu m = case m of
    CatMenu cat -> unorderedList [text "cat", text (sourceType cat),
        text (targetType cat)]

catGroup : Cat -> String -> List (Svg Action) -> Svg Action
catGroup cat tt elts = g [onClick (MenuFor cat)] (title [] [text tt] :: elts)

viewCat : Cat -> Html Action
viewCat cat = let
        -- Build an intermediate SVG fragment.
        -- We return (fragment, width // 64, height // 64)
        go c = case c of
            Id ty -> (catGroup c ("id : " ++ ty) [line [x1 "0", y1 "1",
                                                        x2 "2", y2 "1"] []],
                                                        2, 2)
            Prim s t -> (catGroup c ("prim : " ++ s ++ " → " ++ t)
                         [ line [x1 "0", y1 "1", x2 "0.25", y2 "1"] []
                         , rect [ x "0.25", y "0"
                                , width "1.5", height "2"
                                , rx "0.25", ry "0.25", fill "lightblue"] []
                         , text_ [ alignmentBaseline "middle"
                                 , textAnchor "middle"
                                 , fontFamily "Verdana"
                                 , strokeWidth "0.02"
                                 , x "1", y "1", fontSize "0.25", fill "black"] [text "bloti mlatu"]
                         , line [x1 "1.75", y1 "1", x2 "2", y2 "1"] []
                         ], 2, 2)
            Comp x y -> let
                    (l, lw, lh) = go x
                    (r, rw, rh) = go y
                    tr = g [transform ("translate(" ++ toString lw ++ ")")] [r]
                in (g [] [l, tr], lw + rw, max lh rh)
        (root, w, h) = go cat
        sw = toString (64 * w + 16)
        sh = toString (64 * h + 16)
    in svg
        [version "1.1", width sw, height sh,
         viewBox ("0 0 " ++ sw ++ " " ++ sh)]
        [g [stroke "black", strokeWidth "0.1",
            transform "translate(8,8),scale(64)"] [root]]
        -- [circle [cx "64", cy "64", r "16", color "black", onClick (MenuFor cat)] []]

maybe : (a -> b) -> b -> Maybe a -> b
maybe f b m = case m of
    Just a  -> f a
    Nothing -> b

view : State -> Html Action
view (cat, mm) = div [] [ viewCat cat
                        , maybe viewMenu (text "no menu") mm
                        ]
