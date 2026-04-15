% ============================================================
% RoboCup Prolog - Turn-based 3v3 Grid Soccer with Minimax AI
% ============================================================

:- use_module(library(lists)).

% ============== CONSTANTS ==============
grid_cols(10).
grid_rows(6).
goal_rows([2, 3]).
game_length(40).
half_time_turn(20).
max_stamina(100).
start_stamina(80).
move_cost(5).
recover_amount(10).
contest_cost(10).
minimax_depth(6).
max_consecutive_holds(2).
block_range(3).   % max Chebyshev distance defender may jump to block

% ============== TEAM GEOMETRY ==============
attack_dir(teamA, 1).
attack_dir(teamB, -1).
goal_col(teamA, 9).
goal_col(teamB, 0).
opponent(teamA, teamB).
opponent(teamB, teamA).

in_opp_half(teamA, Col) :- Col >= 5.
in_opp_half(teamB, Col) :- Col =< 4.
in_own_half(teamA, Col) :- Col =< 4.
in_own_half(teamB, Col) :- Col >= 5.

% ============== EVENT LOG ==============
:- dynamic game_event/1.

log_event(Event) :- assertz(game_event(Event)).

collect_events(Events) :-
    findall(E, game_event(E), Events),
    retractall(game_event(_)).

% ============== STATE ==============
% state(Turn, ScoreA-ScoreB, Possession, PlayersA, PlayersB, HoldsA-HoldsB)
% Possession = team(TeamID, Role) | loose(Col, Row)
% Player     = player(Role, Col-Row, Stamina)
% HoldsA/B   = count of consecutive hold actions chosen by that team

initial_players_a([
    player(goalkeeper, 0-3, 80),
    player(defender,   3-3, 80),
    player(forward,    5-3, 80)
]).

initial_players_b([
    player(goalkeeper, 9-3, 80),
    player(defender,   6-3, 80),
    player(forward,    4-3, 80)
]).

initial_state(state(0, 0-0, team(teamA, forward), PA, PB, 0-0)) :-
    initial_players_a(PA),
    initial_players_b(PB).

current_team(state(Turn, _, _, _, _, _), Team) :-
    (0 is Turn mod 2 -> Team = teamA ; Team = teamB).

terminal(state(Turn, _, _, _, _, _)) :-
    game_length(L), Turn >= L.

% ============== LEGAL ACTIONS ==============
% If the acting team's goalkeeper holds the ball, only forced_pass is legal.
legal_actions(state(_, _, team(Team, goalkeeper), _, _, _), Team, [forced_pass]) :- !.
legal_actions(State, Team, Actions) :-
    findall(A,
        ( member(A, [shoot, advance, reposition_up, reposition_down,
                     block, hold, retreat]),
          legal_action(State, Team, A) ),
        Actions).

legal_action(_, _, advance).
legal_action(_, _, retreat).
legal_action(_, _, reposition_up).
legal_action(_, _, reposition_down).
legal_action(state(_, _, _, _, _, HA-_), teamA, hold) :-
    max_consecutive_holds(Max), HA < Max.
legal_action(state(_, _, _, _, _, _-HB), teamB, hold) :-
    max_consecutive_holds(Max), HB < Max.
legal_action(state(_, _, team(Team, Role), PA, PB, _), Team, shoot) :-
    team_players(Team, PA, PB, Players),
    member(player(Role, Col-_, S), Players),
    S > 0,
    in_opp_half(Team, Col).
legal_action(state(_, _, team(Opp, Role), PA, PB, _), Team, block) :-
    opponent(Team, Opp),
    team_players(Opp, PA, PB, OppPlayers),
    member(player(Role, CC-CR, _), OppPlayers),
    in_own_half(Team, CC),
    team_players(Team, PA, PB, OurPlayers),
    member(player(defender, DC-DR, _), OurPlayers),
    block_range(Max),
    chebyshev(DC-DR, CC-CR, D),
    D =< Max.

chebyshev(C1-R1, C2-R2, D) :-
    D is max(abs(C1-C2), abs(R1-R2)).

team_players(teamA, PA, _,  PA).
team_players(teamB, _,  PB, PB).

% ============== APPLY ACTION (pure) ==============

% ---------- advance ----------
apply_action(state(Turn, Score, Poss, PA, PB, Holds), Team, advance,
             state(NewTurn, Score, NewPoss, NPA, NPB, NewHolds)) :-
    attack_dir(Team, Dir),
    ( Team = teamA ->
        move_players(PA, Dir, PA1),
        resolve_contest(Poss, Team, PA1, PB, NPA, NPB, NewPoss)
    ;
        move_players(PB, Dir, PB1),
        resolve_contest(Poss, Team, PA, PB1, NPA, NPB, NewPoss)
    ),
    update_holds(Holds, Team, advance, NewHolds),
    NewTurn is Turn + 1.

% ---------- hold ----------
apply_action(state(Turn, Score, Poss, PA, PB, Holds), teamA, hold,
             state(NewTurn, Score, Poss, NPA, PB, NewHolds)) :-
    recover_team(PA, NPA),
    update_holds(Holds, teamA, hold, NewHolds),
    NewTurn is Turn + 1.
apply_action(state(Turn, Score, Poss, PA, PB, Holds), teamB, hold,
             state(NewTurn, Score, Poss, PA, NPB, NewHolds)) :-
    recover_team(PB, NPB),
    update_holds(Holds, teamB, hold, NewHolds),
    NewTurn is Turn + 1.

% ---------- retreat ----------
apply_action(state(Turn, Score, Poss, PA, PB, Holds), Team, retreat,
             state(NewTurn, Score, NewPoss, NPA, NPB, NewHolds)) :-
    attack_dir(Team, AttackDir),
    Dir is -AttackDir,
    ( Team = teamA ->
        move_players(PA, Dir, PA1),
        pass_backward_if_owned(Poss, Team, PA1, PB, PostPass),
        NPA = PA1, NPB = PB, NewPoss = PostPass
    ;
        move_players(PB, Dir, PB1),
        pass_backward_if_owned(Poss, Team, PB1, PA, PostPass),
        NPA = PA, NPB = PB1, NewPoss = PostPass
    ),
    update_holds(Holds, Team, retreat, NewHolds),
    NewTurn is Turn + 1.

% ---------- shoot ----------
apply_action(state(Turn, SA-SB, team(Team, Role), PA, PB, Holds), Team, shoot, NewState) :-
    team_players(Team, PA, PB, Shooters),
    member(player(Role, _-ShootRow, _), Shooters),
    opponent(Team, Opp),
    team_players(Opp, PA, PB, OppPlayers),
    member(player(goalkeeper, _-GKRow, _), OppPlayers),
    update_holds(Holds, Team, shoot, NewHolds),
    NewTurn is Turn + 1,
    ( GKRow =:= ShootRow ->
        % Save - goalkeeper auto-passes to a teammate
        gk_autopass(Opp, PA, PB, NewPoss),
        NewState = state(NewTurn, SA-SB, NewPoss, PA, PB, NewHolds)
    ;
        ( Team = teamA -> NewSA is SA + 1, NewSB = SB
        ;                 NewSA = SA, NewSB is SB + 1 ),
        after_goal_state(Team, NPA, NPB, NewPoss),
        NewState = state(NewTurn, NewSA-NewSB, NewPoss, NPA, NPB, NewHolds)
    ).

% ---------- forced_pass (GK must release the ball) ----------
apply_action(state(Turn, Score, team(Team, goalkeeper), PA, PB, Holds), Team, forced_pass,
             state(NewTurn, Score, NewPoss, PA, PB, NewHolds)) :-
    gk_autopass(Team, PA, PB, NewPoss),
    update_holds(Holds, Team, forced_pass, NewHolds),
    NewTurn is Turn + 1.

% ---------- reposition_up / reposition_down ----------
apply_action(state(Turn, Score, Poss, PA, PB, Holds), Team, reposition_up,
             state(NewTurn, Score, NewPoss, NPA, NPB, NewHolds)) :-
    reposition(Team, -1, PA, PB, Poss, NPA, NPB, NewPoss),
    update_holds(Holds, Team, reposition_up, NewHolds),
    NewTurn is Turn + 1.
apply_action(state(Turn, Score, Poss, PA, PB, Holds), Team, reposition_down,
             state(NewTurn, Score, NewPoss, NPA, NPB, NewHolds)) :-
    reposition(Team, 1, PA, PB, Poss, NPA, NPB, NewPoss),
    update_holds(Holds, Team, reposition_down, NewHolds),
    NewTurn is Turn + 1.

% ---------- block ----------
apply_action(state(Turn, Score, team(Opp, CarrierRole), PA, PB, Holds), Team, block,
             state(NewTurn, Score, NewPoss, NPA, NPB, NewHolds)) :-
    opponent(Team, Opp),
    team_players(Opp, PA, PB, OppPlayers),
    member(player(CarrierRole, CC-CR, CarrierS), OppPlayers),
    in_own_half(Team, CC),
    team_players(Team, PA, PB, OurPlayers),
    move_role_to(OurPlayers, defender, CC-CR, OurPlayers1),
    member(player(defender, _, DefS), OurPlayers1),
    contest_both(OurPlayers1, OppPlayers, defender, CarrierRole,
                 OurPlayers2, OppPlayers2),
    ( DefS >= CarrierS ->
        NewPoss = team(Team, defender)
    ;   NewPoss = team(Opp, CarrierRole)
    ),
    ( Team = teamA -> NPA = OurPlayers2, NPB = OppPlayers2
    ;                 NPA = OppPlayers2, NPB = OurPlayers2 ),
    update_holds(Holds, Team, block, NewHolds),
    NewTurn is Turn + 1.

% ============== HOLD STREAK ==============
% Increment acting team's counter if action is hold, reset otherwise.
update_holds(HA-HB, teamA, hold, NHA-HB) :- !, NHA is HA + 1.
update_holds(HA-HB, teamB, hold, HA-NHB) :- !, NHB is HB + 1.
update_holds(_-HB,  teamA, _,    0-HB)   :- !.
update_holds(HA-_,  teamB, _,    HA-0).

% ============== MOVEMENT HELPERS ==============
clamp_col(C, NC) :-
    grid_cols(Max), M1 is Max - 1,
    NC is max(0, min(M1, C)).

% Goalkeeper rows are clamped to the goal rows (2..3); others to the grid.
role_row_bounds(goalkeeper, 2, 3) :- !.
role_row_bounds(_, 0, MaxR) :- grid_rows(GR), MaxR is GR - 1.

% Goalkeeper never moves by column (advance / retreat skip them).
move_players([], _, []).
move_players([player(goalkeeper, Pos, S)|T], Dir, [player(goalkeeper, Pos, S)|TN]) :-
    !, move_players(T, Dir, TN).
move_players([player(Role, C-R, S)|T], Dir, [player(Role, NC-R, NS)|TN]) :-
    ( S > 0 ->
        C1 is C + Dir,
        clamp_col(C1, NC),
        move_cost(MC),
        NS is max(0, S - MC)
    ;
        NC = C, NS = S
    ),
    move_players(T, Dir, TN).

move_row([], _, []).
move_row([player(Role, C-R, S)|T], DR, [player(Role, C-NR, NS)|TN]) :-
    ( S > 0 ->
        R1 is R + DR,
        role_row_bounds(Role, MinR, MaxR),
        NR is max(MinR, min(MaxR, R1)),
        move_cost(MC),
        NS is max(0, S - MC)
    ;
        NR = R, NS = S
    ),
    move_row(T, DR, TN).

reposition(teamA, DR, PA, PB, Poss, NPA, NPB, NewPoss) :-
    move_row(PA, DR, PA1),
    resolve_contest(Poss, teamA, PA1, PB, NPA, NPB, NewPoss).
reposition(teamB, DR, PA, PB, Poss, NPA, NPB, NewPoss) :-
    move_row(PB, DR, PB1),
    resolve_contest(Poss, teamB, PA, PB1, NPA, NPB, NewPoss).

recover_team([], []).
recover_team([player(Role, Pos, S)|T], [player(Role, Pos, NS)|TN]) :-
    recover_amount(R), max_stamina(Max),
    NS is min(Max, S + R),
    recover_team(T, TN).

% Pass backward: nearest teammate with a clear path whose column is behind
% the carrier (opposite to attack dir). If none have a clear path, keeps
% the ball with the carrier (prevents long cross-field "teleport" passes).
pass_backward_if_owned(team(Team, CarrierRole), Team, OwnPlayers, OppPlayers, NewPoss) :-
    !,
    member(player(CarrierRole, CC-CR, _), OwnPlayers),
    attack_dir(Team, Dir),
    findall(D-R,
        ( member(player(R, C-RR, _), OwnPlayers),
          R \= CarrierRole,
          ( Dir > 0 -> C < CC ; C > CC ),
          clear_path(CC-CR, C-RR, OppPlayers),
          D is abs(C - CC) ),
        Pairs),
    ( Pairs = [] -> NewPoss = team(Team, CarrierRole)
    ; keysort(Pairs, [_-Best|_]),
      NewPoss = team(Team, Best)
    ).
pass_backward_if_owned(Poss, _, _, _, Poss).

% If opponent has ball, check whether any of our moved players landed on
% the carrier's cell. Higher stamina wins possession; both lose contest_cost.
resolve_contest(team(Opp, CarrierRole), Team, NPA, NPB, NPA2, NPB2, NewPoss) :-
    opponent(Team, Opp),
    !,
    team_players(Opp, NPA, NPB, OppPlayers),
    member(player(CarrierRole, CC-CR, CarrierS), OppPlayers),
    team_players(Team, NPA, NPB, OurPlayers),
    ( member(player(OurRole, CC-CR, OurS), OurPlayers) ->
        contest_cost(CC2),
        NewOurS is max(0, OurS - CC2),
        NewCarrierS is max(0, CarrierS - CC2),
        update_stamina(OurPlayers, OurRole, NewOurS, OurPlayers2),
        update_stamina(OppPlayers, CarrierRole, NewCarrierS, OppPlayers2),
        ( OurS >= CarrierS ->
            NewPoss = team(Team, OurRole)
        ;   NewPoss = team(Opp, CarrierRole)
        ),
        ( Team = teamA ->
            NPA2 = OurPlayers2, NPB2 = OppPlayers2
        ;   NPA2 = OppPlayers2, NPB2 = OurPlayers2
        )
    ;
        NPA2 = NPA, NPB2 = NPB, NewPoss = team(Opp, CarrierRole)
    ).
resolve_contest(Poss, _, NPA, NPB, NPA, NPB, Poss).

update_stamina([], _, _, []).
update_stamina([player(Role, Pos, _)|T], Role, NewS, [player(Role, Pos, NewS)|T]) :- !.
update_stamina([P|T], Role, NewS, [P|TN]) :- update_stamina(T, Role, NewS, TN).

move_role_to([], _, _, []).
move_role_to([player(Role, _, S)|T], Role, NewPos, [player(Role, NewPos, NS)|T]) :-
    !, move_cost(MC), NS is max(0, S - MC).
move_role_to([P|T], Role, NewPos, [P|TN]) :- move_role_to(T, Role, NewPos, TN).

contest_both(Ours, Opps, OurRole, OppRole, Ours2, Opps2) :-
    member(player(OurRole, _, OurS), Ours),
    member(player(OppRole, _, OppS), Opps),
    contest_cost(CC),
    NewOur is max(0, OurS - CC),
    NewOpp is max(0, OppS - CC),
    update_stamina(Ours, OurRole, NewOur, Ours2),
    update_stamina(Opps, OppRole, NewOpp, Opps2).

% After a goal: reset positions; conceding team's forward at center (5,3)
% with the ball. Scoring team's forward is displaced one cell toward their
% own half so the two forwards don't share a cell.
after_goal_state(teamA, NPA, NPB, team(teamB, forward)) :-
    initial_players_a(PA0),
    update_position(PA0, forward, 4-3, NPA),
    initial_players_b(PB0),
    update_position(PB0, forward, 5-3, NPB).
after_goal_state(teamB, NPA, NPB, team(teamA, forward)) :-
    initial_players_a(PA0),
    NPA = PA0,                 % teamA forward already at (5,3) in defaults
    initial_players_b(PB0),
    NPB = PB0.                 % teamB forward at (4,3) in defaults

update_position([], _, _, []).
update_position([player(Role, _, S)|T], Role, NewPos, [player(Role, NewPos, S)|T]) :- !.
update_position([P|T], Role, NewPos, [P|TN]) :- update_position(T, Role, NewPos, TN).

% ============== GOALKEEPER AUTO-PASS ==============
% Prefers nearest teammate with a clear path; falls back to nearest overall.
gk_autopass(GKTeam, PA, PB, team(GKTeam, Best)) :-
    team_players(GKTeam, PA, PB, Own),
    opponent(GKTeam, OppTeam),
    team_players(OppTeam, PA, PB, Opps),
    member(player(goalkeeper, GKPos, _), Own),
    findall(D-Role,
        ( member(player(Role, TPos, _), Own),
          Role \= goalkeeper,
          clear_path(GKPos, TPos, Opps),
          manhattan(GKPos, TPos, D) ),
        Clear),
    ( Clear \= [] ->
        keysort(Clear, [_-Best|_])
    ;
        findall(D-Role,
            ( member(player(Role, TPos, _), Own),
              Role \= goalkeeper,
              manhattan(GKPos, TPos, D) ),
            Any),
        keysort(Any, [_-Best|_])
    ).

manhattan(C1-R1, C2-R2, M) :-
    M is abs(C1-C2) + abs(R1-R2).

clear_path(From, To, Opponents) :-
    line_cells(From, To, Cells),
    \+ ( member(Cell, Cells),
         member(player(_, Cell, _), Opponents) ).

% Chebyshev-stepped line between From and To (endpoints excluded).
line_cells(C1-R1, C2-R2, Cells) :-
    DC is C2 - C1, DR is R2 - R1,
    Steps is max(abs(DC), abs(DR)),
    ( Steps =< 1 -> Cells = []
    ; S1 is Steps - 1,
      numlist(1, S1, Ks),
      findall(CC-RR,
        ( member(K, Ks),
          CC is C1 + round(DC * K / Steps),
          RR is R1 + round(DR * K / Steps) ),
        Cells)
    ).

% ============== EVALUATION ==============
evaluate(state(_, SA-SB, Poss, PA, PB, _), Value) :-
    ScoreDiff is SA - SB,
    ball_info(Poss, PA, PB, BallCol, BallTeam),
    ( BallTeam = teamA -> BallBonus is (BallCol - 5) * 10
    ; BallTeam = teamB -> BallBonus is -(BallCol - 5) * 10
    ; BallBonus = 0
    ),
    total_stamina(PA, StamA),
    total_stamina(PB, StamB),
    StamDiff is StamA - StamB,
    Value is ScoreDiff * 1000 + BallBonus + StamDiff * 2.

ball_info(team(Team, Role), PA, PB, Col, Team) :-
    team_players(Team, PA, PB, Players),
    member(player(Role, Col-_, _), Players).
ball_info(loose(Col, _), _, _, Col, none).

total_stamina([], 0).
total_stamina([player(_, _, S)|T], Total) :-
    total_stamina(T, Rest), Total is Rest + S.

% ============== MINIMAX WITH ALPHA-BETA ==============
minimax(State, 0, _, _, _, none, Value) :- !, evaluate(State, Value).
minimax(State, _, _, _, _, none, Value) :- terminal(State), !, evaluate(State, Value).
minimax(State, Depth, Alpha, Beta, true, BestAction, BestValue) :-
    current_team(State, Team),
    legal_actions(State, Team, Actions),
    Actions \= [], !,
    D1 is Depth - 1,
    max_search(Actions, State, Team, D1, Alpha, Beta, -1000000, none, BestAction, BestValue).
minimax(State, Depth, Alpha, Beta, false, BestAction, BestValue) :-
    current_team(State, Team),
    legal_actions(State, Team, Actions),
    Actions \= [], !,
    D1 is Depth - 1,
    min_search(Actions, State, Team, D1, Alpha, Beta, 1000000, none, BestAction, BestValue).
minimax(State, _, _, _, _, none, Value) :- evaluate(State, Value).

max_search([], _, _, _, _, _, BestV, BestA, BestA, BestV).
max_search([Action|Rest], State, Team, Depth, Alpha, Beta, BestV, BestA, FinalA, FinalV) :-
    apply_action(State, Team, Action, NewState),
    ( terminal(NewState) -> evaluate(NewState, V)
    ; current_team(NewState, NextTeam),
      (NextTeam = teamA -> NextIsMax = true ; NextIsMax = false),
      minimax(NewState, Depth, Alpha, Beta, NextIsMax, _, V)
    ),
    ( V > BestV -> NBV = V, NBA = Action ; NBV = BestV, NBA = BestA ),
    NewAlpha is max(Alpha, NBV),
    ( NewAlpha >= Beta ->
        FinalA = NBA, FinalV = NBV
    ;
        max_search(Rest, State, Team, Depth, NewAlpha, Beta, NBV, NBA, FinalA, FinalV)
    ).

min_search([], _, _, _, _, _, BestV, BestA, BestA, BestV).
min_search([Action|Rest], State, Team, Depth, Alpha, Beta, BestV, BestA, FinalA, FinalV) :-
    apply_action(State, Team, Action, NewState),
    ( terminal(NewState) -> evaluate(NewState, V)
    ; current_team(NewState, NextTeam),
      (NextTeam = teamA -> NextIsMax = true ; NextIsMax = false),
      minimax(NewState, Depth, Alpha, Beta, NextIsMax, _, V)
    ),
    ( V < BestV -> NBV = V, NBA = Action ; NBV = BestV, NBA = BestA ),
    NewBeta is min(Beta, NBV),
    ( Alpha >= NewBeta ->
        FinalA = NBA, FinalV = NBV
    ;
        min_search(Rest, State, Team, Depth, Alpha, NewBeta, NBV, NBA, FinalA, FinalV)
    ).

% ============== LIVE STATE (dynamic predicates) ==============
:- dynamic live_turn/1.
:- dynamic live_score/2.
:- dynamic live_possession/1.
:- dynamic live_player/4.   % Team, Role, Col-Row, Stamina
:- dynamic live_hold/2.     % Team, ConsecutiveHoldCount
:- dynamic game_mode/1.
:- dynamic strategy_aggression/2.

init_live_state :-
    retractall(live_turn(_)),
    retractall(live_score(_, _)),
    retractall(live_possession(_)),
    retractall(live_player(_, _, _, _)),
    retractall(live_hold(_, _)),
    retractall(game_event(_)),
    retractall(game_mode(_)),
    retractall(strategy_aggression(_, _)),
    assertz(live_turn(0)),
    assertz(live_score(teamA, 0)),
    assertz(live_score(teamB, 0)),
    assertz(live_possession(team(teamA, forward))),
    assertz(live_hold(teamA, 0)),
    assertz(live_hold(teamB, 0)),
    assertz(game_mode(ai_vs_ai)),
    assertz(strategy_aggression(teamA, 50)),
    assertz(strategy_aggression(teamB, 50)),
    initial_players_a(PA),
    initial_players_b(PB),
    forall(member(player(R, P, S), PA), assertz(live_player(teamA, R, P, S))),
    forall(member(player(R, P, S), PB), assertz(live_player(teamB, R, P, S))).

current_state(state(Turn, SA-SB, Poss, PA, PB, HA-HB)) :-
    live_turn(Turn),
    live_score(teamA, SA),
    live_score(teamB, SB),
    live_possession(Poss),
    live_hold(teamA, HA),
    live_hold(teamB, HB),
    findall(player(Role, Pos, S), live_player(teamA, Role, Pos, S), PA),
    findall(player(Role, Pos, S), live_player(teamB, Role, Pos, S), PB).

store_state(state(Turn, SA-SB, Poss, PA, PB, HA-HB)) :-
    retractall(live_turn(_)), assertz(live_turn(Turn)),
    retractall(live_score(teamA, _)), assertz(live_score(teamA, SA)),
    retractall(live_score(teamB, _)), assertz(live_score(teamB, SB)),
    retractall(live_possession(_)), assertz(live_possession(Poss)),
    retractall(live_hold(_, _)),
    assertz(live_hold(teamA, HA)),
    assertz(live_hold(teamB, HB)),
    retractall(live_player(teamA, _, _, _)),
    retractall(live_player(teamB, _, _, _)),
    forall(member(player(R, P, S), PA), assertz(live_player(teamA, R, P, S))),
    forall(member(player(R, P, S), PB), assertz(live_player(teamB, R, P, S))).

% ============== RESPONSE BUILDER ==============
player_name(teamA, goalkeeper, player_1A).
player_name(teamA, defender,   player_2A).
player_name(teamA, forward,    player_3A).
player_name(teamB, goalkeeper, player_1B).
player_name(teamB, defender,   player_2B).
player_name(teamB, forward,    player_3B).

team_str(teamA, teamA).
team_str(teamB, teamB).

possession_payload(team(Team, Role), Name, BX, BY) :-
    live_player(Team, Role, C-R, _),
    player_name(Team, Role, Name),
    BX is C * 20, BY is R * 20.
possession_payload(loose(C, R), none, BX, BY) :-
    BX is C * 20, BY is R * 20.

build_game_state(Response) :-
    live_possession(Poss),
    live_score(teamA, SA),
    live_score(teamB, SB),
    possession_payload(Poss, PossName, BX, BY),
    findall(_{name: Name, team: TStr, x: PX, y: PY},
        ( live_player(Team, Role, C-R, _),
          team_str(Team, TStr),
          player_name(Team, Role, Name),
          PX is C * 20,
          PY is R * 20 ),
        Players),
    findall(E, game_event(E), Events),
    Response = _{
        ball: _{x: BX, y: BY, vx: 0, vy: 0},
        possession: PossName,
        players: Players,
        events: Events,
        score: _{teamA: SA, teamB: SB}
    }.

clear_events :- retractall(game_event(_)).

% ============== ACTION SELECTION ==============
choose_action(State, Team, Action) :-
    game_mode(ai_vs_ai), !,
    minimax_choose(State, Team, Action).
choose_action(State, teamA, Action) :-
    game_mode(slider_vs_ai), !,
    slider_choose(State, teamA, Action).
choose_action(State, teamB, Action) :-
    game_mode(slider_vs_ai), !,
    minimax_choose(State, teamB, Action).

minimax_choose(State, Team, Action) :-
    minimax_depth(D),
    (Team = teamA -> IsMax = true ; IsMax = false),
    minimax(State, D, -1000000, 1000000, IsMax, Picked, _),
    ( Picked == none ->
        legal_actions(State, Team, Legal),
        ( Legal = [A|_] -> Action = A ; Action = hold )
    ; Action = Picked
    ).

slider_choose(State, Team, Action) :-
    strategy_aggression(Team, Agg),
    ( Agg >= 50 -> Priority = [shoot, advance, reposition_up, reposition_down,
                                block, hold, retreat]
    ;             Priority = [retreat, hold, reposition_up, reposition_down,
                                block, advance, shoot]
    ),
    legal_actions(State, Team, Legal),
    first_legal(Priority, Legal, Action).

first_legal([A|_], Legal, A) :- member(A, Legal), !.
first_legal([_|T], Legal, A) :- first_legal(T, Legal, A).
first_legal([], [A|_], A) :- !.
first_legal([], [], hold).

% ============== EVENT EMISSION ==============
emit_events(OldState, NewState) :-
    OldState = state(_, OldSA-OldSB, _, _, _, _),
    NewState = state(NewTurn, NewSA-NewSB, _, _, _, _),
    ( NewSA > OldSA -> log_event(event{type:"goal", team:"A"}) ; true ),
    ( NewSB > OldSB -> log_event(event{type:"goal", team:"B"}) ; true ),
    half_time_turn(HT),
    ( NewTurn =:= HT -> log_event(event{type:"half_time"}) ; true ),
    game_length(GL),
    ( NewTurn =:= GL -> log_event(event{type:"full_time"}) ; true ).
