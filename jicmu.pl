:- module(jicmu, [bridi/2]).
:- use_module(library(chr)).

% This isn't builtin?
:- chr_type list(T) ---> [] ; [T|list(T)].

:- chr_type selbri --->
% Essential selbri.
    du ;
% Variables for doing generic work.
    broda ; brode ;
% Isomorphisms.
    dugri ; tenfa ;
% The big list of gismu.
    cinfo ; danlu ; mabru ; mlatu ;
% Converted selbri.
    se(selbri) ; te(selbri) ;
% Logical connectives.
    ja(selbri, selbri) ; je(selbri, selbri).

:- chr_type sumti ---> koha ; kohe ; li(?int).

:- chr_constraint bridi(?selbri, ?list(sumti)).

% Identity is implicit, but we give an idempotence rule to remove redundant
% bridi for efficiency. As a bonus, some CHR implementations may take this to
% mean that bridi/2 is a set, not a multiset; this "set semantics" can lead to
% further speedups.
id @ bridi(B2, B3) \ bridi(B2, B3) <=> true.

% SE conversion.
se @ bridi(se(B2), [T1, T2 | Ts]) <=> bridi(B2, [T2, T1 | Ts]).
te @ bridi(te(B2), [T1, T2, T3 | Ts]) <=> bridi(B2, [T3, T2, T1 | Ts]).

% Absorb {du}.
unify_all([X1, X2 | Xs]) :- X1 = X2, unify_all([X2 | Xs]).
unify_all([_]) :- true.
du @ bridi(du, B3) <=> unify_all(B3).

% Isomorphisms. To prevent looping, we prefer to simplify only, and only
% transform in one direction.
dugri @ bridi(dugri, B3) <=> bridi(te(se(tenfa)), B3).

% Deduction in the animals.
cinfo @ bridi(cinfo, B3) ==> bridi(mlatu, B3).
mlatu @ bridi(mlatu, B3) ==> bridi(mabru, B3).
mabru @ bridi(mabru, B3) ==> bridi(danlu, B3).

% Logical connectives. First, categorical products.
je @ bridi(je(Buha, Buhe), B3) <=> bridi(Buha, B3), bridi(Buhe, B3).
% And categorical coproducts. Note that this elimination relies implicitly on
% backtracking, so it is only portable to CHR with search.
ja @ bridi(ja(Buha, Buhe), B3) <=> bridi(Buha, B3); bridi(Buhe, B3).
