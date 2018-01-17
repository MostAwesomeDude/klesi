import List exposing (isEmpty, length, map, indexedMap, sortBy)
import String exposing (join)
import Tuple exposing (first, second)

import Html exposing (Html, button, div, text, ul, li)
import Html.Events exposing (onClick)
import List.Zipper exposing (Zipper, singleton, toList)
import Svg exposing (Svg, svg, g, title, path, circle, line, rect, text_)
import Svg.Attributes exposing (version, viewBox,
    transform,
    stroke, strokeWidth,
    fontSize,
    color, fill,
    width, height,
    alignmentBaseline, fontFamily, textAnchor,
    cx, cy, r,
    x1, y1, x2, y2,
    x, y, rx, ry,
    d)

main = Html.program {
    init = init,
    update = update,
    subscriptions = subscriptions,
    view = view }

type Ty = Tuple (List String)
        | I

addTy : Ty -> Ty -> Ty
addTy lhs rhs = case (lhs, rhs) of
    (I, I) -> I
    (Tuple xs, I) -> Tuple xs
    (I, Tuple ys) -> Tuple ys
    (Tuple xs, Tuple ys) -> Tuple (xs ++ ys)

lenTy : Ty -> Int
lenTy ty = case ty of
    Tuple xs -> length xs
    I -> 1

type Cat = Id Ty
         | Prim String Ty Ty
         | Comp Cat Cat
         | Prod Cat Cat
         | Braid (List (Int, String))
         | Unit String
         | Counit String

-- Take a position-annotated list and permute it accordingly.
permute : List (Int, a) -> List a
permute xs = map second (sortBy first xs)

sourceType : Cat -> Ty
sourceType cat = case cat of
    Id ty -> ty
    Prim _ ty _ -> ty
    Comp f _ -> sourceType f
    Prod f g -> addTy (sourceType f) (sourceType g)
    Braid tys -> Tuple (map second tys)
    Unit _ -> I
    Counit ty -> Tuple [ty, ty]

targetType : Cat -> Ty
targetType cat = case cat of
    Id ty -> ty
    Prim _ _ ty -> ty
    Comp _ g -> targetType g
    Prod f g -> addTy (targetType f) (targetType g)
    Braid tys -> Tuple (permute tys)
    Unit ty -> Tuple [ty, ty]
    Counit _ -> I

type Menu = CatMenu Cat

type alias State = (Cat, Maybe Menu)

type Action = MenuFor Cat

init : (State, Cmd Action)
init = let
        unit x = Tuple [x]
        id x = Id (unit ("lo'i " ++ x))
        bogus = ((Comp (Braid [(1, "lo'i skari"), (0, "lo'i bloti")])
            (Prod
            (Comp (Prim "bloti mlatu" (unit "lo'i bloti") (unit "lo'i mlatu"))
                  (Comp (id "mlatu")
                        (Prim "mlatu" (unit "lo'i mlatu") (unit "lo'i se mlatu"))))
            (Prim "skari" (unit "lo'i skari") (unit "lo'i se skari"))),
                 Nothing), Cmd.none)
        bogus2 = Comp (Unit "lo'i blanu") (Prod (Prim "blanu" (unit "lo'i blanu") I) (id "blanu"))
        gismu g ts = Prim g (unit ("lo'i " ++ g)) (Tuple ts)
        tavla = gismu "tavla" ["lo'i se tavla", "lo'i te tavla", "lo'i bangu"]
        bangu = gismu "bangu" ["lo'i se bangu", "lo'i te bangu"]
        cat = Comp tavla (Prod (Prod (id "se tavla") (id "te tavla")) bangu)
    in ((cat, Nothing), Cmd.none)

update : Action -> State -> (State, Cmd Action)
update (MenuFor cat) (zd, _) = ((zd, Just (CatMenu cat)), Cmd.none)

subscriptions : State -> Sub Action
subscriptions s = Sub.none

unorderedList : List (Html a) -> Html a
unorderedList xs = ul [] (List.map (\x -> li [] [x]) xs)

formatTy : Ty -> String
formatTy ty = case ty of
    I -> "I"
    Tuple [x] -> x
    Tuple xs -> join " ⊗ " xs

viewMenu : Menu -> Html Action
viewMenu m = case m of
    CatMenu cat -> unorderedList [ text "cat"
                                 , text (formatTy (sourceType cat))
                                 , text (formatTy (targetType cat))
                                 ]

catGroup : Cat -> String -> List (Svg Action) -> Svg Action
catGroup cat tt elts = let
        fullType = join " " [tt, ":", formatTy (sourceType cat), "→",
                             formatTy (targetType cat)]
    in g [onClick (MenuFor cat)] (title [] [text fullType] :: elts)

makeLine : number -> number -> number -> number -> Svg a
makeLine xx1 yy1 xx2 yy2 = line
    [ x1 (toString xx1)
    , y1 (toString yy1)
    , x2 (toString xx2)
    , y2 (toString yy2)
    ] []

hline : number -> number -> number -> Svg a
hline x1 x2 y = makeLine x1 y x2 y

viewCat : Cat -> Html Action
viewCat cat = let
        -- Build an intermediate SVG fragment.
        -- We return (fragment, width, height) in small tiles.
        go c = case c of
            Id ty -> case ty of
                I -> (text "", 0, 0)
                _ -> (catGroup c "id" [hline 0 2 1], 2, 2)
            Prim name s t -> let
                    h = max (lenTy s) (lenTy t)
                    lineAt x1 x2 i _ = hline x1 x2 (toFloat i * 2 + 1)
                in (catGroup c name
                              [ case s of
                                  I -> text ""
                                  Tuple tys -> g [] (indexedMap (lineAt 0 0.25) tys)
                              , rect [ x "0.25", y "0.25"
                                     , width "1.5", height (toString (toFloat h * 2 - 0.5))
                                     , rx "0.25", ry "0.25", fill "pink"] []
                              , text_ [ alignmentBaseline "middle"
                                      , textAnchor "middle"
                                      , fontFamily "Verdana"
                                      , strokeWidth "0.02"
                                      , x "1", y (toString h), fontSize "0.2"
                                      , fill "black"] [text name]
                              , case t of
                                  I -> text ""
                                  Tuple tys -> g [] (indexedMap (lineAt 1.75 2) tys)
                              ], 2, 2 * h)
            Comp x y -> let
                    (l, lw, lh) = go x
                    (r, rw, rh) = go y
                    tr = g [transform ("translate(" ++ toString lw ++ ")")] [r]
                in (g [] [l, tr], lw + rw, max lh rh)
            Prod x y -> let
                    (t, tw, th) = go x
                    (b, bw, bh) = go y
                    tb = g [transform ("translate(0, " ++ toString th ++ ")")] [b]
                    -- Extend the shorter of the two.
                    ex = if tw < bw then hline tw bw 1
                         else if tw > bw then hline bw tw (th + 1)
                         else text ""
                in (g [] [t, tb, ex], max tw bw, th + bh)
            Braid tys -> let
                    size = length tys + 2
                    sty = sourceType c
                    tty = targetType c
                    f x = x * 2 + 1
                    lines = indexedMap (\i (j, _) -> makeLine 0 (f i) size (f j)) tys
                in (catGroup c "braid" lines, size, size)
            -- We draw these half-circles counter-clockwise.
            Unit ty -> let
                    wire = path [d "M 2 1 A 1 1 0 0 0 2 3", fill "none"] []
                in (catGroup c "unit" [wire], 2, 4)
            Counit ty -> let
                    wire = path [d "M 0 3 A 1 1 0 0 0 0 1", fill "none"] []
                in (catGroup c "counit" [wire], 2, 4)
        (root, w, h) = go cat
        sw = toString (64 * w + 16)
        sh = toString (64 * h + 16)
        mainsvg = svg
            [version "1.1", width sw, height sh,
             viewBox ("0 0 " ++ sw ++ " " ++ sh)]
            [g [stroke "black", strokeWidth "0.1",
                transform "translate(8,8),scale(64)"] [root]]
    in mainsvg
        -- [circle [cx "64", cy "64", r "16", color "black", onClick (MenuFor cat)] []]

maybe : (a -> b) -> b -> Maybe a -> b
maybe f b m = case m of
    Just a  -> f a
    Nothing -> b

view : State -> Html Action
view (cat, mm) = div [] [ viewCat cat
                        , maybe viewMenu (text "no menu") mm
                        ]
