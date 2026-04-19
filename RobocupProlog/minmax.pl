% init state

% first half: ball with player_2A (which is the team A forward) at (5,3)
initial_state_first_half(State) :-
    State = state(
        1,
        0-0,
        [p(defender, 3, 2, 100), p(forward, 5, 3, 100)],
        [p(defender, 8, 3, 100), p(forward, 6, 2, 100)],
        ball(5, 3, player_2A)
    ).

% second half: ball with player_2B (team B forward) at (6,3)
initial_state_second_half(ScoreA-ScoreB, State) :-
    State = state(
        16,
        ScoreA-ScoreB,
        [p(defender, 3, 3, 100), p(forward, 5, 2, 100)],
        [p(defender, 8, 2, 100), p(forward, 6, 3, 100)],
        ball(6, 3, player_2B)
    ).

% grid display: a 10x6 grid (cols are 0-9 & rows 0-5)
% players 1A, 1B are defender and players 2A, 2B are forward 
% GA is goal for team A which is at col 0 and rows 2-3
% GB is goal for team B which is at col 9 and rows 2-3
% ball is shown as lowercase suffix on possessor cell: Example: "2A*" means player_2A has the ball


display_state(State) :-
    State = state(Turn, ScoreA-ScoreB, PlayersA, PlayersB, Ball),
    format("~n=== Turn ~w | Score  A:~w  B:~w ===~n", [Turn, ScoreA, ScoreB]),
    Ball = ball(_, _, Possessor),
    format("    Ball possessor: ~w~n~n", [Possessor]),
    print_column_header,
    numlist(0, 5, Rows),
    maplist(print_row(PlayersA, PlayersB, Ball), Rows),
    print_column_header,
    nl.

print_column_header :-
    write("    "),
    numlist(0, 9, Cols),
    maplist([C]>>(format(" ~w  ", [C])), Cols),
    nl.

print_row(PlayersA, PlayersB, Ball, Row) :-
    format("~w | ", [Row]),
    numlist(0, 9, Cols),
    maplist(print_cell(PlayersA, PlayersB, Ball, Row), Cols),
    nl.

print_cell(PlayersA, PlayersB, Ball, Row, Col) :-
    cell_content(Col, Row, PlayersA, PlayersB, Ball, Content),
    format("~w ", [Content]).


%  priority for cell content: players > goals > empty.
%  * is appended to possessor cell.

cell_content(Col, Row, PlayersA, _PlayersB, Ball, Content) :-
    PlayersA = [p(defender, Col, Row, _) | _],
    !,
    (Ball = ball(Col, Row, player_1A) -> Content = '[1A*]' ; Content = '[1A ]').

cell_content(Col, Row, PlayersA, _PlayersB, Ball, Content) :-
    PlayersA = [_, p(forward, Col, Row, _)],
    !,
    (Ball = ball(Col, Row, player_2A) -> Content = '[2A*]' ; Content = '[2A ]').

cell_content(Col, Row, _PlayersA, PlayersB, Ball, Content) :-
    PlayersB = [p(defender, Col, Row, _) | _],
    !,
    (Ball = ball(Col, Row, player_1B) -> Content = '[1B*]' ; Content = '[1B ]').

cell_content(Col, Row, _PlayersA, PlayersB, Ball, Content) :-
    PlayersB = [_, p(forward, Col, Row, _)],
    !,
    (Ball = ball(Col, Row, player_2B) -> Content = '[2B*]' ; Content = '[2B ]').

cell_content(0, Row, _, _, _, '[GA ]') :-
    (Row =:= 2 ; Row =:= 3), !.

cell_content(9, Row, _, _, _, '[GB ]') :-
    (Row =:= 2 ; Row =:= 3), !.

cell_content(_, _, _, _, _, '[.  ]').



:- if(\+ current_predicate(numlist/3)).
numlist(L, H, []) :- L > H, !.
numlist(L, H, [L|T]) :- L =< H, L1 is L + 1, numlist(L1, H, T).
:- endif.

% in this portion, extract the player data
player_data(player_1A, state(_, _, [P|_], _, _), P).
player_data(player_2A, state(_, _, [_,P], _, _), P).
player_data(player_1B, state(_, _, _, [P|_], _), P).
player_data(player_2B, state(_, _, _, [_,P], _), P).

% assign team
team(player_1A, a).  team(player_2A, a).
team(player_1B, b).  team(player_2B, b).

% role of a player atom
role(player_1A, defender). role(player_2A, forward).
role(player_1B, defender). role(player_2B, forward).

% teammate atom given a player atom.
teammate(player_1A, player_2A). teammate(player_2A, player_1A).
teammate(player_1B, player_2B). teammate(player_2B, player_1B).

% opponent atoms for a given player atom.
opponents(player_1A, [player_1B, player_2B]).
opponents(player_2A, [player_1B, player_2B]).
opponents(player_1B, [player_1A, player_2A]).
opponents(player_2B, [player_1A, player_2A]).

% which role does the teammate have
teammate_role(Player, Role) :-
    teammate(Player, TM),
    role(TM, Role).


in_bounds(Col, Row) :-
    Col >= 0, Col =< 9,
    Row >= 0, Row =< 5.

%  direction -> delta
dir_delta(up,    0, -1).
dir_delta(down,  0,  1).
dir_delta(left, -1,  0).
dir_delta(right, 1,  0).


%  stamina cost to move
move_cost(Player, State, Cost) :-
    State = state(_, _, _, _, ball(_, _, Player)),
    !,
    Cost = 8.
move_cost(_, _, 3).


% adjacency where manhattan dist. is 1
adjacent(C1, R1, C2, R2) :-
    Dist is abs(C1 - C2) + abs(R1 - R2),
    Dist =:= 1.


%  team A attacks the right goal which at col 9, rows 2-3
%  team B is vice versa but at col 0
attacking_goal_cells(a, [goal(9,2), goal(9,3)]).
attacking_goal_cells(b, [goal(0,2), goal(0,3)]).


% nearest goal cell (manhattan distance) for a player
nearest_goal_cell(Player, Col, Row, GCol, GRow) :-
    team(Player, Team),
    attacking_goal_cells(Team, Goals),
    findall(D-goal(GC,GR),
        (member(goal(GC,GR), Goals),
         D is abs(Col-GC) + abs(Row-GR)),
        Pairs),
    min_member(_-goal(GCol,GRow), Pairs).


shoot_path_clear(Player, Col, Row, GCol, GRow, State) :-
    Row =:= GRow,                        % must be same row
    opponents(Player, Opps),
    path_cols(Col, GCol, PathCols),      % cols strictly between
    \+ (
        member(OppAtom, Opps),
        player_data(OppAtom, State, p(_, OC, OR, _)),
        OR =:= Row,
        (member(OC, PathCols) ; OC =:= GCol)
    ).

path_cols(C1, C2, Cols) :-
    C1 < C2, !,
    Lo is C1 + 1, Hi is C2 - 1,
    (Lo > Hi -> Cols = [] ; numlist(Lo, Hi, Cols)).
path_cols(C1, C2, Cols) :-
    C1 > C2,
    Lo is C2 + 1, Hi is C1 - 1,
    (Lo > Hi -> Cols = [] ; numlist(Lo, Hi, Cols)).


pass_result(Player, State, TMRole, Result) :-
    player_data(Player, State, p(_, PC, PR, _)),
    teammate(Player, TM),
    player_data(TM, State, p(TMRole, TC, TR, _)),
    (PR =:= TR -> true ; PC =:= TC),    % change ; to -> true ;
    opponents(Player, Opps),
    findall(Dist-OppAtom,
        (   member(OppAtom, Opps),
            player_data(OppAtom, State, p(_, OC, OR, _)),
            on_pass_path(PC, PR, TC, TR, OC, OR),
            Dist is abs(PC - OC) + abs(PR - OR)
        ),
        Interceptors),
    (   Interceptors = []
    ->  Result = clear
    ;   min_member(_-First, Interceptors),
        Result = intercepted(First)
    ).

%  is (OC, OR) strictly between (PC,PR) and (TC,TR) on a shared row or column
on_pass_path(PC, PR, TC, PR, OC, OR) :-   % same row
    OR =:= PR,
    strictly_between(PC, TC, OC).
on_pass_path(PC, PR, PC, TR, OC, OR) :-   % same col
    OC =:= PC,
    strictly_between(PR, TR, OR).

strictly_between(A, B, X) :-
    ( A < B -> X > A, X < B ; X > B, X < A ).

% check if legal direction
% move(Dir)
legal_action(Player, move(Dir), State) :-
    dir_delta(Dir, DC, DR),
    player_data(Player, State, p(_, Col, Row, Stamina)),
    NewCol is Col + DC,
    NewRow is Row + DR,
    in_bounds(NewCol, NewRow),
    \+ teammate_on_cell(Player, NewCol, NewRow, State),
    move_cost(Player, State, Cost),
    Stamina >= Cost.

% hold
legal_action(_Player, hold, _State).

% contest
legal_action(Player, contest, State) :-
    player_data(Player, State, p(_, Col, Row, Stamina)),
    Stamina >= 15,
    State = state(_, _, _, _, ball(_, _, BallHolder)),
    team(BallHolder, OppTeam),
    team(Player, MyTeam),
    OppTeam \= MyTeam,                  % opponent has ball
    player_data(BallHolder, State, p(_, BC, BR, _)),
    adjacent(Col, Row, BC, BR).

% shoot
legal_action(Player, shoot, State) :-
    State = state(_, _, _, _, ball(_, _, Player)),  % must possess
    player_data(Player, State, p(_, Col, Row, Stamina)),
    Stamina >= 10,
    nearest_goal_cell(Player, Col, Row, GCol, GRow),
    Dist is abs(Col - GCol) + abs(Row - GRow),
    Dist =< 4,
    shoot_path_clear(Player, Col, Row, GCol, GRow, State).

% pass(Role)
legal_action(Player, pass(TMRole), State) :-
    State = state(_, _, _, _, ball(_, _, Player)),  % must possess
    player_data(Player, State, p(_, _, _, Stamina)),
    Stamina >= 5,
    teammate_role(Player, TMRole),
    pass_result(Player, State, TMRole, _).  % path exists

%  check if a teammate on a given cell?
teammate_on_cell(Player, Col, Row, State) :-
    teammate(Player, TM),
    player_data(TM, State, p(_, Col, Row, _)).



legal_actions(Player, State, Actions) :-
    all_candidate_actions(Player, Actions_candidates),
    findall(A,
        (member(A, Actions_candidates), legal_action(Player, A, State)),
        RawActions),
    (   RawActions = []
    ->  Actions = [hold]
    ;   Actions = RawActions).

all_candidate_actions(Player, Candidates) :-
    teammate_role(Player, TMRole),
    Candidates = [
        move(up), move(down), move(left), move(right),
        hold,
        contest,
        shoot,
        pass(TMRole)
    ].



%  order of operations per team turn: 1. resolve simultaneous move conflict which is when it same target cell 2. Apply defender action
%  then apply forward action  3. Check goal scored

apply_team_actions(Team, act(DefAct, FwdAct), State, NewState) :-
    resolve_conflict(Team, DefAct, FwdAct, State, ResolvedDef, ResolvedFwd),
    apply_player_action(Team, defender, ResolvedDef, State,  State1),
    apply_player_action(Team, forward,  ResolvedFwd, State1, State2),
    check_goal(State2, NewState).

% resolve conflict in order of operations
resolve_conflict(Team, move(DDir), move(FDir), State,
                 move(DDir), hold_penalised(FCost)) :-
    player_atoms(Team, DefAtom, FwdAtom),
    player_data(DefAtom, State, p(_, DC, DR, _)),
    player_data(FwdAtom, State, p(_, FC, FR, _)),
    dir_delta(DDir, DDC, DDR),
    dir_delta(FDir, FDC, FDR),
    NewDC is DC + DDC, NewDR is DR + DDR,
    NewFC is FC + FDC, NewFR is FR + FDR,
    NewDC =:= NewFC, NewDR =:= NewFR,   % same target cell
    !,
    move_cost(FwdAtom, State, FCost).

resolve_conflict(_, DefAct, FwdAct, _, DefAct, FwdAct).


player_atoms(a, player_1A, player_2A).
player_atoms(b, player_1B, player_2B).

apply_player_action(Team, Role, move(Dir), State, NewState) :-
    player_atoms(Team, DefAtom, FwdAtom),
    (Role = defender -> Atom = DefAtom ; Atom = FwdAtom),
    player_data(Atom, State, p(Role, Col, Row, Stamina)),
    dir_delta(Dir, DC, DR),
    NewCol is Col + DC,
    NewRow is Row + DR,
    move_cost(Atom, State, Cost),
    NewStamina is max(0, Stamina - Cost),
    % move ball with carrier
    State = state(T, Score, PA, PB, ball(BC, BR, Poss)),
    (Poss = Atom
    ->  NewBall = ball(NewCol, NewRow, Atom)
    ;   NewBall = ball(BC, BR, Poss)),
    update_player(Team, Role, p(Role, NewCol, NewRow, NewStamina),
                  State, TempState),
    TempState = state(T, Score, PA2, PB2, _),
    NewState = state(T, Score, PA2, PB2, NewBall).

% hold
apply_player_action(Team, Role, hold, State, NewState) :-
    player_atoms(Team, DefAtom, FwdAtom),
    (Role = defender -> Atom = DefAtom ; Atom = FwdAtom),
    player_data(Atom, State, p(Role, Col, Row, Stamina)),
    NewStamina is min(100, Stamina + 10),
    update_player(Team, Role, p(Role, Col, Row, NewStamina),
                  State, NewState).

apply_player_action(Team, forward, hold_penalised(Cost), State, NewState) :-
    player_atoms(Team, _, FwdAtom),
    player_data(FwdAtom, State, p(forward, Col, Row, Stamina)),
    NewStamina is max(0, Stamina - Cost),
    update_player(Team, forward, p(forward, Col, Row, NewStamina),
                  State, NewState).

% contest
apply_player_action(Team, Role, contest, State, NewState) :-
    player_atoms(Team, DefAtom, FwdAtom),
    (Role = defender -> Atom = DefAtom ; Atom = FwdAtom),
    player_data(Atom, State, p(Role, Col, Row, Stamina)),
    State = state(T, Score, PA, PB, ball(BC, BR, OppAtom)),
    player_data(OppAtom, State, p(OppRole, OC, OR, OppStamina)),
    % both lose 15 stamina
    NewStamina    is max(0, Stamina    - 15),
    NewOppStamina is max(0, OppStamina - 15),
    % higher stamina wins; defender wins ties
    (   Stamina > OppStamina
    ->  Winner = Atom
    ;   OppStamina > Stamina
    ->  Winner = OppAtom
    ;   % tie — defender wins
        (role(Atom, defender) -> Winner = Atom ; Winner = OppAtom)
    ),
    
    % update staminas
    update_player(Team, Role,
                  p(Role, Col, Row, NewStamina), State, S1),
    opponent_team(Team, OppTeam),
    update_player(OppTeam, OppRole,
                  p(OppRole, OC, OR, NewOppStamina), S1, S2),
    
    % transfer ball if contestant wins
    S2 = state(T, Score, PA2, PB2, ball(BC, BR, _)),
    NewState = state(T, Score, PA2, PB2, ball(BC, BR, Winner)).

% shoot
apply_player_action(Team, Role, shoot, State, NewState) :-
    player_atoms(Team, DefAtom, FwdAtom),
    (Role = defender -> Atom = DefAtom ; Atom = FwdAtom),
    player_data(Atom, State, p(Role, Col, Row, Stamina)),
    nearest_goal_cell(Atom, Col, Row, GCol, GRow),
    NewStamina is max(0, Stamina - 10),
    update_player(Team, Role,
                  p(Role, Col, Row, NewStamina), State, TempState),
    TempState = state(T, Score, PA2, PB2, _),

    % ball moves to goal cell, still possessed by shooter
    % for this, goal detection in check_goal/2 will catch it
    NewState = state(T, Score, PA2, PB2, ball(GCol, GRow, Atom)).

% pass(TMRole)
apply_player_action(Team, Role, pass(TMRole), State, NewState) :-
    player_atoms(Team, DefAtom, FwdAtom),
    (Role = defender -> Atom = DefAtom ; Atom = FwdAtom),
    player_data(Atom, State, p(Role, Col, Row, Stamina)),
    NewStamina is max(0, Stamina - 5),
    teammate(Atom, TM),
    player_data(TM, State, p(TMRole, TC, TR, _)),
    pass_result(Atom, State, TMRole, Result),
    update_player(Team, Role,
                  p(Role, Col, Row, NewStamina), State, TempState),
    TempState = state(T, Score, PA2, PB2, ball(_, _, _)),
    (   Result = clear
    ->  NewState = state(T, Score, PA2, PB2, ball(TC, TR, TM))
    ;   Result = intercepted(IntAtom)
    ->  player_data(IntAtom, State, p(_, IC, IR, _)),
        NewState = state(T, Score, PA2, PB2, ball(IC, IR, IntAtom))
    ).

%  detect goal then reset pos., score ++ , etc
check_goal(State, NewState) :-
    State = state(T, SA-SB, _, _, ball(BC, BR, Scorer)),
    goal_cell(BC, BR, ScoringTeam),
    !,

    % increment score
    (ScoringTeam = a
    ->  NewSA is SA + 1, NewSB = SB
    ;   NewSA = SA,      NewSB is SB + 1),

    % preserve staminas
    State = state(_, _, [p(_,_,_,StamD_A), p(_,_,_,StamF_A)],
                        [p(_,_,_,StamD_B), p(_,_,_,StamF_B)], _),
    scored_on_team(ScoringTeam, LosingTeam),
    losing_forward_atom(LosingTeam, FwdAtom),
    half_of_turn(T, Half),
    kickoff_forward_pos(Half, LosingTeam, FwdCol, FwdRow),
    reset_players(Half,
                  StamD_A, StamF_A, StamD_B, StamF_B,
                  PA_new, PB_new),
    NewState = state(T, NewSA-NewSB, PA_new, PB_new,
                     ball(FwdCol, FwdRow, FwdAtom)).

check_goal(State, State). % no goal, state unchanged

goal_cell(0, 2, b).  goal_cell(0, 3, b).  % col 0 which is for team b score
goal_cell(9, 2, a).  goal_cell(9, 3, a).  % vice versa

scored_on_team(a, b).  % A scored, B kicked off
scored_on_team(b, a).

losing_forward_atom(a, player_2A).
losing_forward_atom(b, player_2B).

half_of_turn(T, first_half)  :- T =< 15, !.
half_of_turn(_, second_half).

kickoff_forward_pos(first_half,  a, 5, 3).
kickoff_forward_pos(first_half,  b, 6, 2).
kickoff_forward_pos(second_half, a, 5, 2).
kickoff_forward_pos(second_half, b, 6, 3).

reset_players(first_half,
    StamD_A, StamF_A, StamD_B, StamF_B,
    [p(defender,3,2,StamD_A), p(forward,5,3,StamF_A)],
    [p(defender,8,3,StamD_B), p(forward,6,2,StamF_B)]).
reset_players(second_half,
    StamD_A, StamF_A, StamD_B, StamF_B,
    [p(defender,3,3,StamD_A), p(forward,5,2,StamF_A)],
    [p(defender,8,2,StamD_B), p(forward,6,3,StamF_B)]).

opponent_team(a, b).
opponent_team(b, a).



update_player(a, defender, NewP,
              state(T, Score, [_|Fwd], PB, Ball),
              state(T, Score, [NewP|Fwd], PB, Ball)).

update_player(a, forward, NewP,
              state(T, Score, [Def|_], PB, Ball),
              state(T, Score, [Def,NewP], PB, Ball)).

update_player(b, defender, NewP,
              state(T, Score, PA, [_|Fwd], Ball),
              state(T, Score, PA, [NewP|Fwd], Ball)).

update_player(b, forward, NewP,
              state(T, Score, PA, [Def|_], Ball),
              state(T, Score, PA, [Def,NewP], Ball)).



%  priority list: ordered sequence of actions

%  team A
priority_list(a, forward,  attacking,
    [shoot, pass(defender), contest,
     move(right), move(up), move(down), move(left), hold]).

priority_list(a, forward,  supportive,
    [pass(defender), hold, shoot, contest,
     move(right), move(up), move(down), move(left)]).

priority_list(a, defender, aggressive,
    [contest, shoot, pass(forward),
     move(right), move(up), move(down), move(left), hold]).

priority_list(a, defender, conservative,
    [hold, contest, pass(forward),
     move(left), move(up), move(down), move(right)]).

% team B (left/right swapped)
priority_list(b, forward,  attacking,
    [shoot, pass(defender), contest,
     move(left), move(up), move(down), move(right), hold]).

priority_list(b, forward,  supportive,
    [pass(defender), hold, shoot, contest,
     move(left), move(up), move(down), move(right)]).

priority_list(b, defender, aggressive,
    [contest, shoot, pass(forward),
     move(left), move(up), move(down), move(right), hold]).

priority_list(b, defender, conservative,
    [hold, contest, pass(forward),
     move(right), move(up), move(down), move(left)]).


%  priority agent action selection: returns first legal action

priority_action(Team, Role, Preset, State, Action) :-
    player_atoms(Team, DefAtom, FwdAtom),
    (Role = defender -> Atom = DefAtom ; Atom = FwdAtom),
    priority_list(Team, Role, Preset, List),
    first_legal(Atom, List, State, Action).

first_legal(Atom, [H|_], State, H) :-
    legal_action(Atom, H, State), !.
first_legal(Atom, [_|T], State, Action) :-
    first_legal(Atom, T, State, Action).


%  Team action for priority agent
priority_team_action(Team, DefPreset, FwdPreset, State,
                     act(DefAct, FwdAct)) :-
    priority_action(Team, defender, DefPreset, State, DefAct),
    priority_action(Team, forward,  FwdPreset, State, FwdAct).

% config
:- dynamic active_preset/3.

active_preset(a, forward,  attacking).
active_preset(a, defender, aggressive).
active_preset(b, forward,  attacking).
active_preset(b, defender, aggressive).

set_preset(Team, Role, Preset) :-
    retract(active_preset(Team, Role, _)),
    assertz(active_preset(Team, Role, Preset)).

% get team action using active presets
priority_team_action_default(Team, State, TeamAct) :-
    active_preset(Team, defender, DefPreset),
    active_preset(Team, forward,  FwdPreset),
    once(priority_team_action(Team, DefPreset, FwdPreset, State, TeamAct)).


% run_priority_game: runs a full 30-turn game
run_priority_game :-
    initial_state_first_half(S0),
    format("~n*** FIRST HALF ***~n~n", []),
    run_turns(S0, 15, S_half),
    S_half = state(_, SA-SB, _, _, _),
    format("~n*** HALF TIME | Score A:~w B:~w ***~n~n", [SA, SB]),
    initial_state_second_half(SA-SB, S16),
    run_turns(S16, 30, S_final),
    S_final = state(_, FA-FB, _, _, _),
    format("~n=== FULL TIME: A ~w - ~w B ===~n", [FA, FB]).

run_turns(State, MaxTurn, State) :-
    State = state(T, _, _, _, _),
    T > MaxTurn, !.

run_turns(State, MaxTurn, Final) :-
    State = state(T, _, _, _, _),
    T =< MaxTurn,
    display_state(State),
    once(priority_team_action_default(a, State, ActA)),
    once(apply_team_actions(a, ActA, State, S1)),
    once(priority_team_action_default(b, S1, ActB)),
    once(apply_team_actions(b, ActB, S1, S2)),
    S2 = state(_, Score2, PA2, PB2, Ball2),
    T1 is T + 1,
    S3 = state(T1, Score2, PA2, PB2, Ball2),
    run_turns(S3, MaxTurn, Final).



% evaluation func (leaf-node heuristic): minimax maximizes for A, minimizes for B

% terminal eval: if turn > 30, only score difference matters
evaluate(State, Value) :-
    State = state(T, _, _, _, _),
    T > 30,
    !,
    eval_score(State, Value).

% non terminal eval
evaluate(State, Value) :-
    eval_score(State, ScoreVal),
    eval_possession(State, PossVal),
    eval_ball_advancement(State, AdvVal),
    eval_shooting_threat(State, ShootVal),
    eval_pressure(State, PressVal),
    eval_ball_dist_opponents(State, BallDistVal),
    eval_forward_positioning(State, FwdPosVal),
    eval_stamina(State, StamVal),
    Value is ScoreVal + PossVal + AdvVal + ShootVal
            + PressVal + BallDistVal + FwdPosVal + StamVal.


eval_score(state(_, SA-SB, _, _, _), Value) :-
    Value is (SA - SB) * 10000.


% +500 if A has ball, -500 if B has ball
eval_possession(state(_, _, _, _, ball(_, _, Poss)), Value) :-
    team(Poss, Team),
    (Team = a -> Value = 500 ; Value = -500).


eval_ball_advancement(state(_, _, _, _, ball(BC, _, Poss)), Value) :-
    team(Poss, Team),
    (Team = a
    ->  Value is BC * 50
    ;   Value is -((9 - BC) * 50)
    ).


% +300 if A's ball-holder has a legal shoot
% -300 if B's ball-holder has a legal shoot
eval_shooting_threat(State, Value) :-
    State = state(_, _, _, _, ball(_, _, Poss)),
    team(Poss, Team),
    (   legal_action(Poss, shoot, State)
    ->  (Team = a -> Value = 300 ; Value = -300)
    ;   Value = 0
    ).


% +100 per A player adjacent to B ball-holder
% -100 per B player adjacent to A ball-holder
eval_pressure(State, Value) :-
    State = state(_, _, PA, PB, ball(_, _, Poss)),
    team(Poss, Team),
    (   Team = b
    ->  % B has ball, count A players adjacent to B ball-holder
        player_data(Poss, State, p(_, BC, BR, _)),
        count_adjacent_players(PA, BC, BR, Count),
        Value is Count * 100
    ;   % A has ball, count B players adjacent to A ball-holder
        player_data(Poss, State, p(_, BC, BR, _)),
        count_adjacent_players(PB, BC, BR, Count),
        Value is -(Count * 100)
    ).

% count how many players in a player list are adjacent to (col, row).
count_adjacent_players([], _, _, 0).
count_adjacent_players([p(_, PC, PR, _)|Rest], Col, Row, Count) :-
    count_adjacent_players(Rest, Col, Row, RestCount),
    Dist is abs(PC - Col) + abs(PR - Row),
    (Dist =:= 1 -> Count is RestCount + 1 ; Count = RestCount).

% ball dist from nearest opponent with signed + - and use manhattan
eval_ball_dist_opponents(State, Value) :-
    State = state(_, _, PA, PB, ball(BC, BR, Poss)),
    team(Poss, Team),
    (   Team = a
    ->  min_dist_to_players(BC, BR, PB, MinDist),
        Value is MinDist * 10
    ;   min_dist_to_players(BC, BR, PA, MinDist),
        Value is -(MinDist * 10)
    ).

% minimum manhattan dist from (col,row) to any player in list
min_dist_to_players(Col, Row, Players, MinDist) :-
    findall(D,
        (member(p(_, PC, PR, _), Players),
         D is abs(Col - PC) + abs(Row - PR)),
        Dists),
    min_list(Dists, MinDist).

% forward positioning
eval_forward_positioning(state(_, _, [_, p(forward, AC, _, _)],
                                     [_, p(forward, BC, _, _)], _), Value) :-
    Value is AC * 20 - (9 - BC) * 20.

% stamina advantage = (sum A stam - sum B stam)x2
eval_stamina(state(_, _, [p(_,_,_,SD_A), p(_,_,_,SF_A)],
                         [p(_,_,_,SD_B), p(_,_,_,SF_B)], _), Value) :-
    SumA is SD_A + SF_A,
    SumB is SD_B + SF_B,
    Value is (SumA - SumB) * 2.

% minimax vs priority mode and minimax vs minimax mode
:- dynamic search_depth/1.
search_depth(4).

set_search_depth(D) :-
    retractall(search_depth(_)),
    assertz(search_depth(D)).


% select mode
:- dynamic play_mode/1.
play_mode(minimax_vs_priority). % default

set_play_mode(Mode) :-
    member(Mode, [minimax_vs_priority, minimax_vs_minimax]),
    retractall(play_mode(_)),
    assertz(play_mode(Mode)).

% returns best team A action 
best_move_a(State, BestAct, BestValue) :-
    search_depth(Depth),
    ordered_team_actions(a, State, Actions),
    alpha_beta_max_root(Actions, State, Depth, -999999, 999999,
                        none, _, BestAct, BestValue).

% iterate over team A's actions at the root 
alpha_beta_max_root([], _, _, _, _, none, _, _, _) :- !, fail.  % no valid actions
alpha_beta_max_root([], _, _, _, _, BestSoFar, BestValSoFar,
                    BestSoFar, BestValSoFar).
alpha_beta_max_root([Act|Rest], State, Depth, Alpha, Beta,
                    BestSoFar, BestValSoFar, BestAct, BestValue) :-
    (   apply_team_actions(a, Act, State, S1),
        play_mode(Mode),
        ab_after_a(Mode, S1, State, Depth, Alpha, Beta, Val)
    ->  (   (BestSoFar = none ; Val > Alpha)
        ->  NewAlpha is max(Alpha, Val),
            NewBest = Act, NewBestVal = Val
        ;   NewAlpha = Alpha, NewBest = BestSoFar, NewBestVal = BestValSoFar
        ),
        (   NewAlpha >= Beta
        ->  BestAct = NewBest, BestValue = NewBestVal
        ;   alpha_beta_max_root(Rest, State, Depth, NewAlpha, Beta,
                                NewBest, NewBestVal, BestAct, BestValue)
        )
    ;   % action failed to apply so skip it
        alpha_beta_max_root(Rest, State, Depth, Alpha, Beta,
                            BestSoFar, BestValSoFar, BestAct, BestValue)
    ).


% for minimax_vs_priority mode: B uses fixed policy (no branching).
% but in minimax_vs_minimax mode: B branches with minimization.

% B uses priority-list agent mode
ab_after_a(minimax_vs_priority, S1, _OrigState, Depth, Alpha, Beta, Val) :-
    once(priority_team_action_default(b, S1, ActB)),
    apply_team_actions(b, ActB, S1, S2),
    advance_turn(S2, S3),
    Depth1 is Depth - 1,
    ab_value(S3, Depth1, Alpha, Beta, Val).

% B branches (minimizer) mode
ab_after_a(minimax_vs_minimax, S1, _OrigState, Depth, Alpha, Beta, Val) :-
    ordered_team_actions(b, S1, ActionsB),
    alpha_beta_min_list(ActionsB, S1, Depth, Alpha, Beta, 999999, Val).

% minimizer iteration for team B actions
alpha_beta_min_list([], _, _, _, _, BestVal, BestVal).
alpha_beta_min_list([ActB|Rest], S1, Depth, Alpha, Beta, BestSoFar, Val) :-
    (   apply_team_actions(b, ActB, S1, S2),
        advance_turn(S2, S3),
        Depth1 is Depth - 1,
        ab_value(S3, Depth1, Alpha, Beta, V)
    ->  NewBest is min(BestSoFar, V),
        NewBeta is min(Beta, NewBest),
        (   NewBeta =< Alpha
        ->  Val = NewBest
        ;   alpha_beta_min_list(Rest, S1, Depth, Alpha, NewBeta, NewBest, Val)
        )
    ;   alpha_beta_min_list(Rest, S1, Depth, Alpha, Beta, BestSoFar, Val)
    ).

% recursive eval where base case is depth 0/gameover and recur: team a maximizes then B responds
ab_value(State, 0, _, _, Val) :-
    !, evaluate(State, Val).

ab_value(State, _, _, _, Val) :-
    State = state(T, _, _, _, _),
    T > 30,
    !, evaluate(State, Val).

ab_value(State, Depth, Alpha, Beta, Val) :-
    ordered_team_actions(a, State, ActionsA),
    ab_max_list(ActionsA, State, Depth, Alpha, Beta, -999999, Val).

% maximizer iteration for team A actions
ab_max_list([], _, _, _, _, BestVal, BestVal).
ab_max_list([ActA|Rest], State, Depth, Alpha, Beta, BestSoFar, Val) :-
    (   apply_team_actions(a, ActA, State, S1),
        play_mode(Mode),
        ab_after_a(Mode, S1, State, Depth, Alpha, Beta, V)
    ->  NewBest is max(BestSoFar, V),
        NewAlpha is max(Alpha, NewBest),
        (   NewAlpha >= Beta
        ->  Val = NewBest
        ;   ab_max_list(Rest, State, Depth, NewAlpha, Beta, NewBest, Val)
        )
    ;   ab_max_list(Rest, State, Depth, Alpha, Beta, BestSoFar, Val)
    ).

%advance turn counter
advance_turn(state(T, Score, PA, PB, Ball),
             state(T1, Score, PA, PB, Ball)) :-
    T1 is T + 1.

% team actions in order: shoot, contest, pass, move, hold
ordered_team_actions(Team, State, Ordered) :-
    player_atoms(Team, DefAtom, FwdAtom),
    legal_actions(DefAtom, State, DefActions),
    legal_actions(FwdAtom, State, FwdActions),
    findall(act(DA, FA),
        (   member(DA, DefActions),
            member(FA, FwdActions),
            \+ (DA == contest, FA == contest),
            once(apply_team_actions(Team, act(DA, FA), State, _))
        ),
        AllActs),
    (   AllActs = []
    ->  Ordered = [act(hold, hold)]
    ;   map_priority_sort(AllActs, Ordered)
    ).

% sort team actions by priority score (lower = searched first)
map_priority_sort(Acts, Sorted) :-
    maplist(tag_priority, Acts, Tagged),
    msort(Tagged, SortedTagged),
    maplist(untag, SortedTagged, Sorted).

tag_priority(Act, Prio-Act) :-
    Act = act(DA, FA),
    action_priority(DA, PD),
    action_priority(FA, PF),
    Prio is PD + PF.

untag(_-Act, Act).

% priority ordering: lower number = higher priority = searched first
action_priority(shoot, 0).
action_priority(contest, 1).
action_priority(pass(_), 2).
action_priority(move(_), 3).
action_priority(hold, 4).
action_priority(hold_penalised(_), 5).

% game loop for minimax so team A uses minimax and team B uses whetever the playmode is
run_minimax_game :-
    initial_state_first_half(S0),
    format("~n*** FIRST HALF (Minimax) ***~n~n", []),
    run_minimax_turns(S0, 15, S_half),
    S_half = state(_, SA-SB, _, _, _),
    format("~n*** HALF TIME | Score A:~w B:~w ***~n~n", [SA, SB]),
    initial_state_second_half(SA-SB, S16),
    run_minimax_turns(S16, 30, S_final),
    S_final = state(_, FA-FB, _, _, _),
    format("~n=== FULL TIME: A ~w - ~w B ===~n", [FA, FB]).

run_minimax_turns(State, MaxTurn, State) :-
    State = state(T, _, _, _, _),
    T > MaxTurn, !.

run_minimax_turns(State, MaxTurn, Final) :-
    State = state(T, _, _, _, _),
    T =< MaxTurn,
    display_state(State),
    
    % Team A: minimax
    best_move_a(State, ActA, _Val),
    format("  A plays: ~w~n", [ActA]),
    apply_team_actions(a, ActA, State, S1),
    
    % Team B: depends on mode
    play_mode(Mode),
    team_b_action(Mode, S1, ActB, S2),
    format("  B plays: ~w~n", [ActB]),
    S2 = state(_, Score2, PA2, PB2, Ball2),
    T1 is T + 1,
    S3 = state(T1, Score2, PA2, PB2, Ball2),
    run_minimax_turns(S3, MaxTurn, Final).

%  Team B action selection based on mode.
team_b_action(minimax_vs_priority, S1, ActB, S2) :-
    once(priority_team_action_default(b, S1, ActB)),
    apply_team_actions(b, ActB, S1, S2).

team_b_action(minimax_vs_minimax, S1, ActB, S2) :-
    best_move_b(S1, ActB, _),
    apply_team_actions(b, ActB, S1, S2).

% best move for team B (used in mode 2)
best_move_b(State, BestAct, BestValue) :-
    search_depth(Depth),
    ordered_team_actions(b, State, Actions),
    alpha_beta_min_root(Actions, State, Depth, -999999, 999999,
                        none, _, BestAct, BestValue).

alpha_beta_min_root([], _, _, _, _, none, _, _, _) :- !, fail.
alpha_beta_min_root([], _, _, _, _, BestSoFar, BestValSoFar,
                    BestSoFar, BestValSoFar).
alpha_beta_min_root([ActB|Rest], State, Depth, Alpha, Beta,
                    BestSoFar, BestValSoFar, BestAct, BestValue) :-
    (   apply_team_actions(b, ActB, State, S1),
        advance_turn(S1, S2),
        Depth1 is Depth - 1,
        ab_value(S2, Depth1, Alpha, Beta, Val)
    ->  (   (BestSoFar = none ; Val < Beta)
        ->  NewBeta is min(Beta, Val),
            NewBest = ActB, NewBestVal = Val
        ;   NewBeta = Beta, NewBest = BestSoFar, NewBestVal = BestValSoFar
        ),
        (   Alpha >= NewBeta
        ->  BestAct = NewBest, BestValue = NewBestVal
        ;   alpha_beta_min_root(Rest, State, Depth, Alpha, NewBeta,
                                NewBest, NewBestVal, BestAct, BestValue)
        )
    ;   alpha_beta_min_root(Rest, State, Depth, Alpha, Beta,
                            BestSoFar, BestValSoFar, BestAct, BestValue)
    ).

:- dynamic live_state/1.
:- dynamic game_event/1.
:- dynamic game_mode/1.
:- dynamic strategy_aggression/2.
:- dynamic kickoff_pending/0.

% init
init_live_state :-
    retractall(live_state(_)),
    retractall(game_event(_)),
    retractall(game_mode(_)),
    retractall(strategy_aggression(_, _)),
    retractall(kickoff_pending),
    assertz(game_mode(ai_vs_ai)),
    assertz(strategy_aggression(teamA, 50)),
    assertz(strategy_aggression(teamB, 50)),
    set_search_depth(2),
    retractall(play_mode(_)),
    assertz(play_mode(minimax_vs_minimax)),
    initial_state_first_half(S0),
    assertz(live_state(S0)),
    assertz(kickoff_pending).

current_state(S) :- live_state(S).

store_state(S) :-
    retractall(live_state(_)),
    assertz(live_state(S)).

clear_events :- retractall(game_event(_)).

log_event(E) :- assertz(game_event(E)).

% terminal/turn order
terminal(state(T, _, _, _, _)) :- T > 30.

current_team(_, round).


% kickoff frame: no actions are taken, we just show the reset layout
choose_action(State, _Team, combined(skipped, skipped)) :-
    kickoff_pending, !,
    State = state(T, SA-SB, _, _, ball(_, _, Poss)),
    format(user_output,
        "~n-- Turn ~w | Score A:~w B:~w | Ball:~w | (kickoff frame) --~n",
        [T, SA, SB, Poss]),
    flush_output(user_output).

choose_action(State, _Team, combined(ActA, ActB)) :-
    ( game_mode(Mode) -> true ; Mode = ai_vs_ai ),
    sync_play_mode(Mode),
    pick_team_actions(Mode, State, ActA, ActB),
    log_agent_choice(Mode, State, ActA, ActB).

% goal just happened: score went up for either team
goal_occurred(state(_, SA0-SB0, _, _, _), state(_, SA1-SB1, _, _, _)) :-
    (SA1 > SA0 ; SB1 > SB0).

% log each team's action 
log_agent_choice(Mode, state(T, SA-SB, _, _, ball(_, _, Poss)), ActA, ActB) :-
    agent_label(a, Mode, LabelA),
    agent_label(b, Mode, LabelB),
    format(user_output,
        "~n-- Turn ~w | Score A:~w B:~w | Ball:~w | Mode:~w --~n",
        [T, SA, SB, Poss, Mode]),
    format(user_output, "   Team A [~w]: ~w~n", [LabelA, ActA]),
    ( ActB == skipped
    ->  format(user_output,
            "   Team B [~w]: (skipped, kickoff after A scored)~n", [LabelB])
    ;   format(user_output, "   Team B [~w]: ~w~n", [LabelB, ActB])
    ),
    flush_output(user_output).

agent_label(b, slider_vs_ai, priority) :- !.
agent_label(_, _,            minimax).


sync_play_mode(slider_vs_ai) :- !,
    retractall(play_mode(_)),
    assertz(play_mode(minimax_vs_priority)),
    set_search_depth(2).
sync_play_mode(_) :-
    retractall(play_mode(_)),
    assertz(play_mode(minimax_vs_minimax)),
    set_search_depth(2).

% ai vs ai: both minimax
pick_team_actions(ai_vs_ai, State, ActA, ActB) :- !,
    pick_minimax_a(State, ActA),
    once(apply_team_actions(a, ActA, State, S1)),
    ( goal_occurred(State, S1)
    ->  ActB = skipped
    ;   pick_minimax_b(S1, ActB)
    ).

% slider vs ai : A is minimax, B is priority list (aggression-driven)
pick_team_actions(slider_vs_ai, State, ActA, ActB) :- !,
    pick_minimax_a(State, ActA),
    once(apply_team_actions(a, ActA, State, S1)),
    ( goal_occurred(State, S1)
    ->  ActB = skipped
    ;   sync_team_presets(b),
        once(priority_team_action_default(b, S1, ActB))
    ).

% unknown mode ->  full minimax fallback
pick_team_actions(_, State, ActA, ActB) :-
    pick_minimax_a(State, ActA),
    once(apply_team_actions(a, ActA, State, S1)),
    ( goal_occurred(State, S1)
    ->  ActB = skipped
    ;   pick_minimax_b(S1, ActB)
    ).

pick_minimax_a(State, Act) :-
    ( catch(best_move_a(State, A, _), _, fail) -> Act = A
    ; Act = act(hold, hold)
    ).

pick_minimax_b(State, Act) :-
    ( catch(best_move_b(State, A, _), _, fail) -> Act = A
    ; Act = act(hold, hold)
    ).


% kickoff frame: retract the flag, return the state unchanged, emit
apply_action(State, _Team, _Action, NewState) :-
    retract(kickoff_pending), !,
    NewState = State,
    log_event(event{type:"kickoff"}).

% A already scored during choose_action's look-ahead, so B was skipped
apply_action(State, _Team, combined(ActA, skipped), NewState) :- !,
    once(apply_team_actions(a, ActA, State, S1)),
    advance_turn(S1, S2),
    maybe_halftime(S2, NewState),
    log_event(event{type:"kickoff"}).

% Normal round (both teams act, advance turn, maybe halftime-swap)
apply_action(State, _Team, combined(ActA, ActB), NewState) :-
    once(apply_team_actions(a, ActA, State, S1)),
    once(apply_team_actions(b, ActB, S1, S2)),
    advance_turn(S2, S3),
    maybe_halftime(S3, NewState),
    (   goal_occurred(S1, S2)
    ->  log_event(event{type:"kickoff"})
    ;   NewState = state(16, _, _, _, _)
    ->  log_event(event{type:"kickoff"})
    ;   true
    ).

% when turn becomes 16, reset positions but keep score
maybe_halftime(state(16, Score, _, _, _), S16) :- !,
    initial_state_second_half(Score, S16).
maybe_halftime(S, S).

% strat -> priority reset
aggression_presets(Agg, attacking,  aggressive)  :- Agg >= 67, !.
aggression_presets(Agg, attacking,  conservative) :- Agg >= 34, !.
aggression_presets(_,   supportive, conservative).

team_atom_to_key(a, teamA).
team_atom_to_key(b, teamB).

sync_team_presets(Team) :-
    team_atom_to_key(Team, Key),
    ( strategy_aggression(Key, Agg) -> true ; Agg = 50 ),
    aggression_presets(Agg, FwdP, DefP),
    retractall(active_preset(Team, forward,  _)),
    retractall(active_preset(Team, defender, _)),
    assertz(active_preset(Team, forward,  FwdP)),
    assertz(active_preset(Team, defender, DefP)).

% events

emit_events(state(_, OldSA-OldSB, _, _, _),
            state(NewT, NewSA-NewSB, _, _, _)) :-
    ( NewSA > OldSA -> log_event(event{type:"goal", team:"A"}) ; true ),
    ( NewSB > OldSB -> log_event(event{type:"goal", team:"B"}) ; true ),
    ( NewT =:= 16   -> log_event(event{type:"half_time"})      ; true ),
    ( NewT  >  30   -> log_event(event{type:"full_time"})      ; true ).

% json res

build_game_state(Response) :-
    current_state(state(_, SA-SB, PA, PB, ball(BC, BR, Poss))),
    PA = [p(_, DAC, DAR, _), p(_, FAC, FAR, _)],
    PB = [p(_, DBC, DBR, _), p(_, FBC, FBR, _)],
    BX  is BC  * 20, BY  is BR  * 20,
    DAX is DAC * 20, DAY is DAR * 20,
    FAX is FAC * 20, FAY is FAR * 20,
    DBX is DBC * 20, DBY is DBR * 20,
    FBX is FBC * 20, FBY is FBR * 20,
    Players = [
        _{name: player_1A, team: teamA, x: DAX, y: DAY},
        _{name: player_2A, team: teamA, x: FAX, y: FAY},
        _{name: player_1B, team: teamB, x: DBX, y: DBY},
        _{name: player_2B, team: teamB, x: FBX, y: FBY}
    ],
    findall(E, game_event(E), Events),
    Response = _{
        ball:       _{x: BX, y: BY, vx: 0, vy: 0},
        possession: Poss,
        players:    Players,
        events:     Events,
        score:      _{teamA: SA, teamB: SB}
    }.
