import List exposing (isEmpty, length)
import String exposing (join)

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

type Ty = Tuple (List String)

addTy : Ty -> Ty -> Ty
addTy (Tuple xs) (Tuple ys) = Tuple (xs ++ ys)

type Cat = Id Ty
         | Prim String Ty Ty
         | Comp Cat Cat
         | Prod Cat Cat
         -- | Braid [Int]

sourceType : Cat -> Ty
sourceType cat = case cat of
    Id ty -> ty
    Prim _ ty _ -> ty
    Comp f _ -> sourceType f
    Prod f g -> addTy (sourceType f) (sourceType g)

targetType : Cat -> Ty
targetType cat = case cat of
    Id ty -> ty
    Prim _ _ ty -> ty
    Comp _ g -> targetType g
    Prod f g -> addTy (targetType f) (targetType g)

type Menu = CatMenu Cat

type alias State = (Cat, Maybe Menu)

type Action = MenuFor Cat

init : (State, Cmd Action)
init = let
        unit x = Tuple [x]
    in ((Prod (Prim "jai se skari" (unit "lo'i bloti") (unit "lo'i se skari"))
        (Comp (Prim "bloti mlatu" (unit "lo'i bloti") (unit "lo'i mlatu"))
              (Comp (Id (unit "lo'i mlatu"))
                    (Prim "mlatu" (unit "lo'i mlatu") (unit "lo'i se mlatu")))),
             Nothing), Cmd.none)

update : Action -> State -> (State, Cmd Action)
update (MenuFor cat) (zd, _) = ((zd, Just (CatMenu cat)), Cmd.none)

subscriptions : State -> Sub Action
subscriptions s = Sub.none

unorderedList : List (Html a) -> Html a
unorderedList xs = ul [] (List.map (\x -> li [] [x]) xs)

formatTy : Ty -> String
formatTy (Tuple xs) = case xs of
    [x] -> x
    _ -> join "⊗" xs

lenTy : Ty -> Int
lenTy (Tuple xs) = length xs

viewMenu : Menu -> Html Action
viewMenu m = case m of
    CatMenu cat -> unorderedList [text "cat", text (formatTy (sourceType cat)),
        text (formatTy (targetType cat))]

catGroup : Cat -> String -> List (Svg Action) -> Svg Action
catGroup cat tt elts = g [onClick (MenuFor cat)] (title [] [text tt] :: elts)

viewCat : Cat -> Html Action
viewCat cat = let
        -- Build an intermediate SVG fragment.
        -- We return (fragment, width // 64, height // 64)
        go c = case c of
            Id ty -> (catGroup c ("id : " ++ formatTy ty) [line [x1 "0", y1 "1",
                                                        x2 "2", y2 "1"] []],
                                                        2, 2)
            Prim name s t -> (catGroup c (name ++ " : " ++ formatTy s ++ " → " ++ formatTy t)
                              [ line [x1 "0", y1 "1", x2 "0.25", y2 "1"] []
                              , rect [ x "0.25", y "0.25"
                                     , width "1.5", height "1.5"
                                     , rx "0.25", ry "0.25", fill "pink"] []
                              , text_ [ alignmentBaseline "middle"
                                      , textAnchor "middle"
                                      , fontFamily "Verdana"
                                      , strokeWidth "0.02"
                                      , x "1", y "1", fontSize "0.2"
                                      , fill "black"] [text name]
                              , line [x1 "1.75", y1 "1", x2 "2", y2 "1"] []
                              ], 2, 2)
            Comp x y -> let
                    (l, lw, lh) = go x
                    (r, rw, rh) = go y
                    tr = g [transform ("translate(" ++ toString lw ++ ")")] [r]
                in (g [] [l, tr], lw + rw, max lh rh)
            Prod x y -> let
                    (t, tw, th) = go x
                    (b, bw, bh) = go y
                    tb = g [transform ("translate(0, " ++ toString th ++ ")")] [b]
                in (g [] [t, tb], max tw bw, th + bh)
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
