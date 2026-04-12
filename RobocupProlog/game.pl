field_size(200, 120).
goal_width(25).
game_duration(350). % game time (ticks)

% ==========================================
% TEAM STRATEGY PARAMETERS (0-100, default 50)
% ==========================================
% team_strategy(Team, Aggression, PassingAccuracy, PressingIntensity, DefensiveLine, KickPower)
:- dynamic team_strategy/6.
team_strategy(teamA, 50, 50, 50, 50, 50).
team_strategy(teamB, 50, 50, 50, 50, 50).

set_team_strategy(Team, Aggression, PassingAccuracy, PressingIntensity, DefensiveLine, KickPower) :-
    retractall(team_strategy(Team, _, _, _, _, _)),
    assertz(team_strategy(Team, Aggression, PassingAccuracy, PressingIntensity, DefensiveLine, KickPower)).

% needed by optimizer save/restore (also declared in server.pl)
:- dynamic current_time/1.

% for the logtext in unity UI
:- dynamic game_event/1.

log_event(Event) :-
    assertz(game_event(Event)).

collect_events(Events) :-
    findall(E, game_event(E), Events),
    retractall(game_event(_)).

% ball state which is ball(X, Y, VX, VY, Possession).
:- dynamic ball/5.

% start ball at player6A
ball(100, 60, 0, 0, player_6A).

% makes the ball stay within the bounds of field
adjust_position(X, Y, NewX, NewY) :-
    (Y < 0 -> NewY = 0;
    Y > 120 -> NewY = 120;
    NewY = Y),
    field_size(MaxX, _),
    NewX is min(max(X, 0), MaxX).

% update ball position based on 2 cases:
% Case 1: Ball is stopped: do nothing
update_ball :-
    ball(_, _, VX, VY, _),
    VX =:= 0,
    VY =:= 0,
    !.

% Case 2: Ball is moving: update
update_ball :-
    retract(ball(X, Y, VX, VY, Possession)),

    TempX is X + VX,
    TempY is Y + VY,

    adjust_position(TempX, TempY, NewX, NewY),

    TempVX is VX * 0.9,
    TempVY is VY * 0.9,

    field_size(MaxX, MaxY),

    % when bounce off X walls --> negate velocity X
    ( (NewX =< 0.01 ; NewX >= MaxX - 0.01) -> NewVX is -TempVX ; NewVX = TempVX ),
    ( (NewY =< 0.01 ; NewY >= MaxY - 0.01) -> NewVY = 0         ; NewVY = TempVY ),

    ( (abs(NewVX) < 0.1, abs(NewVY) < 0.1) ->
        FinalVX = 0, FinalVY = 0, NewPossession = none
    ;
        FinalVX = NewVX, FinalVY = NewVY, NewPossession = Possession
    ),

    assertz(ball(NewX, NewY, FinalVX, FinalVY, NewPossession)),
    format('Ball has been moved to position: (~w, ~w)~n', [NewX, NewY]),
    check_goal.


kick_direction(Team, Direction) :-
    % Team A kicks towards right  and B toward left
    (Team = teamA -> Direction = right; Direction = left).

% The players kick action (strategy-aware)
kick(Player) :-
    player(Team,Player,Position,Stamina,_,_),

    kick_direction(Team, Direction),
    team_strategy(Team, _, PassingAccuracy, _, _, KickPower),

    % Kick power scales VX (0.5x at 0, 1.0x at 50, 1.5x at 100)
    PowerMult is 0.5 + KickPower / 100,
    BaseVX is 5 + Stamina / 10,
    (Direction = left -> NewVX is -BaseVX * PowerMult; NewVX is BaseVX * PowerMult),

    % Passing accuracy scales VY spread (higher = tighter)
    AccMult is 1.5 - PassingAccuracy / 100,
    (Position = midfielder ->
        BaseRange is max(1, round(10 * AccMult))
    ;
        BaseRange is max(1, round(20 * AccMult))
    ),
    NegRange is -BaseRange,
    random_between(NegRange, BaseRange, R),
	NewVY is R,
	retract(ball(X, Y, _,_,_)),
    assertz(ball(X, Y, NewVX, NewVY, none)),
    format('Player ~w kicks the ball ~w as a ~w~n', [Player, Direction,Position]),
    update_ball.



% player defs
:- dynamic player/6.
player(teamA, player_1A, goalkeeper, 80, 10, 60).
player(teamA, player_2A, defender, 80, 45, 20).
player(teamA, player_3A, defender, 80, 45, 40).
player(teamA, player_4A, defender, 80, 45, 60).
player(teamA, player_5A, defender, 80, 45, 80).
player(teamA, player_6A, midfielder, 80, 100, 30).
player(teamA, player_7A, midfielder, 80, 100, 60).
player(teamA, player_8A, midfielder, 80, 100, 90).
player(teamA, player_9A, forward, 80, 150, 30).
player(teamA, player_10A, forward, 80, 150, 60).
player(teamA, player_11A, forward, 80, 150, 90).
player(teamB, player_1B, goalkeeper, 80, 190, 60).
player(teamB, player_2B, defender, 80, 155, 20).
player(teamB, player_3B, defender, 80, 155, 40).
player(teamB, player_4B, defender, 80, 155, 60).
player(teamB, player_5B, defender, 80, 155, 80).
player(teamB, player_6B, midfielder, 80, 100, 30).
player(teamB, player_7B, midfielder, 80, 100, 60).
player(teamB, player_8B, midfielder, 80, 100, 90).
player(teamB, player_9B, forward, 80, 50, 30).
player(teamB, player_10B, forward, 80, 50, 60).
player(teamB, player_11B, forward, 80, 50, 90).

% define init. positions for all players
init_pos(teamA, player_1A, 10, 60).
init_pos(teamA, player_2A, 45, 20).
init_pos(teamA, player_3A, 45, 40).
init_pos(teamA, player_4A, 45, 60).
init_pos(teamA, player_5A, 45, 80).
init_pos(teamA, player_6A, 100, 30).
init_pos(teamA, player_7A, 100, 60).
init_pos(teamA, player_8A, 100, 90).
init_pos(teamA, player_9A, 150, 30).
init_pos(teamA, player_10A, 150, 60).
init_pos(teamA, player_11A, 150, 90).
init_pos(teamB, player_1B, 190, 60).
init_pos(teamB, player_2B, 155, 20).
init_pos(teamB, player_3B, 155, 40).
init_pos(teamB, player_4B, 155, 60).
init_pos(teamB, player_5B, 155, 80).
init_pos(teamB, player_6B, 100, 30).
init_pos(teamB, player_7B, 100, 60).
init_pos(teamB, player_8B, 100, 90).
init_pos(teamB, player_9B, 50, 30).
init_pos(teamB, player_10B, 50, 60).
init_pos(teamB, player_11B, 50, 90).

% Intercept radius (strategy-aware via aggression)
base_intercept_radius(forward, 2).
base_intercept_radius(midfielder, 3).
base_intercept_radius(defender, 5).

intercept_radius(Team, Position, Radius) :-
    base_intercept_radius(Position, Base),
    team_strategy(Team, Aggression, _, _, _, _),
    Radius is Base * (0.5 + Aggression / 100).

distance(X1, Y1, X2, Y2, Dist) :-
    DX is X2 - X1,
    DY is Y2 - Y1,
    Dist is sqrt(DX*DX + DY*DY).

% detecting goals with goalkeeper save logic + correct scoring assignment
check_goal :-
    ball(BallX, BallY, _, _, _),
    field_size(FieldLength, FieldWidth),
    goal_width(GoalWidth),

    % check if the ball is in the scoring range for Team A (this is the right side)
    ( BallX >= FieldLength, abs(BallY - (FieldWidth / 2)) =< (GoalWidth / 2) ->
        % Attempt save for Team B goalkeeper
        player(teamB, Goalkeeper, goalkeeper, _, GKX, GKY),
        distance(GKX, GKY, BallX, BallY, Dist),
        save_radius(Radius),
        (Dist =< Radius ->
            attempt_save(Goalkeeper),
            write('Save attempt by Team B goalkeeper! No goal.~n')
        ;
           reset_players_ball, write('Goal scored by Team A!'), nl, update_score(teamA),
           log_event(event{type:"goal", team:"A"})

        )
    ;
      % Check if the ball is in the scoring range for Team B (left side of the field)
      BallX =< 0, abs(BallY - (FieldWidth / 2)) =< (GoalWidth / 2) ->
        % Attempt save for Team A goalkeeper
        player(teamA, Goalkeeper, goalkeeper, _, GKX, GKY),
        distance(GKX, GKY, BallX, BallY, Dist),
        save_radius(Radius),
        (Dist =< Radius ->
            attempt_save(Goalkeeper),
            write('Save attempt by Team A goalkeeper! No goal.~n')

        ;
           reset_players_ball, write('Goal scored by Team B!'), nl, update_score(teamB),
            log_event(event{type:"goal", team:"B"})
        );
      true
    ).

% player speed based on stamina
speed(Stamina, Speed) :-
    Speed is 15+Stamina / 10. % Ex: 10 stamina = 1 speed unit.

% how far the player moves in one step toward the ball
move_step(PX, PY, FutureX, FutureY, Speed, NewX, NewY) :-
    % Calculate direction vector (dx, dy) to the future ball position
    DX is FutureX - PX,
    DY is FutureY - PY,
    Distance is sqrt(DX*DX + DY*DY), % Calculate the total distance to the target

    % Normalize the direction and scale by the player's speed to get the move step
    (Distance > 0 ->
        Factor is Speed / Distance, % Factor to normalize movement by speed
        NewDX is DX * Factor,
        NewDY is DY * Factor
    ;
        NewDX = 0, NewDY = 0
    ),

    % Calculate the new position after moving the step
    NewX is PX + NewDX,
    NewY is PY + NewDY.

% Stamina recovery
recover_stamina(Player) :-
    player(Team, Player, Position, Stam, PX, PY),
    NewStamina is min(80, Stam + 5), % Recovery rate
    retract(player(Team, Player, Position, Stam, PX, PY)),
    assertz(player(Team, Player, Position, NewStamina, PX, PY)).

recover_all_players :-
    findall(Player, player(_, Player, _, _, _, _), Players),
    maplist(recover_stamina, Players).

% Score tracking
:- dynamic score/2.
score(teamA, 0).
score(teamB, 0).

update_score(Team) :-
    retract(score(Team, Current)),
    NewScore is Current + 1,
    assertz(score(Team, NewScore)),
    score(teamA, ScoreA),
    score(teamB, ScoreB),
    format('Updated Score: Team A ~w - Team B ~w~n', [ScoreA, ScoreB]),
    reset_players_ball.

% Adjust defender X position based on defensive line strategy
adjusted_defender_x(Team, defender, X, AdjX) :-
    !,
    team_strategy(Team, _, _, _, DefensiveLine, _),
    (Team = teamA ->
        AdjX is X + (DefensiveLine - 50) * 0.6
    ;
        AdjX is X - (DefensiveLine - 50) * 0.6
    ).
adjusted_defender_x(_, _, X, X).

% Reset players and ball (uses defensive line strategy for defender positions)
reset_players_ball :-
    retract(ball(_,_,_,_,_)),
    assertz(ball(100, 60, 0, 0, none)),
    forall(player(Team, Player, Pos, Stam, _, _),
        (init_pos(Team, Player, InitX, InitY),
         adjusted_defender_x(Team, Pos, InitX, AdjX),
         retract(player(Team, Player, Pos, Stam, _, _)),
         assertz(player(Team, Player, Pos, 80, AdjX, InitY)))).

% Goalkeeper save
save_radius(5).  % Goalkeeper can save the ball if it's within 5 units

attempt_save(Goalkeeper) :-
    player(Team, Goalkeeper, goalkeeper, Stam, PX, PY),
    ball(BX, BY, VX, VY, _),
    save_radius(Radius),
    distance(PX, PY, BX, BY, Dist),
    Dist =< Radius,
    % If ball is within the save radius, goalkeeper attempts a save
    NewStamina is max(0, Stam - 5),
    retract(player(Team, Goalkeeper, goalkeeper, Stam, PX, PY)),
    assertz(player(Team, Goalkeeper, goalkeeper, NewStamina, PX, PY)),
    % Stop the ball (set velocity to 0) and gain possession
    retract(ball(BX, BY, VX, VY, _)),
    assertz(ball(BX, BY, 0, 0, Goalkeeper)),
    format('~w made a save at (~w, ~w)!~n', [Goalkeeper, BX, BY]).

% Players who can intercept the ball (strategy-aware via aggression)
players_who_can_intercept(Players) :-
    ball(BX, BY, VX, VY, _),
    FutureX is BX + VX,
    FutureY is BY + VY,
    findall(Player, (
        player(Team, Player, Position, _, PX, PY),
        (Position = defender; Position = midfielder; Position = forward),
        intercept_radius(Team, Position, Radius),
        distance(PX, PY, FutureX, FutureY, Dist),
        Dist =< Radius
    ), Players).

% Check if any player is within range of the ball (strategy-aware via pressing intensity)
players_near_ball(Players) :-
    ball(BX, BY, _, _, _),
    findall(Player, (
        player(Team, Player, _, _, PX, PY),
        team_strategy(Team, _, _, PressingIntensity, _, _),
        Range is 25 + PressingIntensity / 2,
        distance(PX, PY, BX, BY, Dist),
        Dist =< Range
    ), Players).

% Players who can intercept the ball and update possession (strategy-aware)
intercept(Player) :-
    player(Team, Player, Position, _, PX, PY),
    ball(BX, BY, VX, VY, _),
    FutureX is BX + VX,
    FutureY is BY + VY,
    intercept_radius(Team, Position, Radius),
    distance(PX, PY, FutureX, FutureY, Dist),
    Dist =< Radius,
    retract(ball(BX, BY, VX, VY, _)),
    assertz(ball(PX, PY, 0, 0, Player)),
    format('~w intercepted the ball!~n', [Player]).

% Move to intercept the ball if possible (strategy-aware)
move_to_intercept(Player) :-
    player(Team, Player, Position, Stam, PX, PY),
    (Stam > 0 ->
        ball(X, Y, VX, VY, _),
        FutureX is X + VX,
        FutureY is Y + VY,
        intercept_radius(Team, Position, Radius),
        distance(PX, PY, FutureX, FutureY, Dist),
        (Dist =< Radius ->
            intercept(Player)  % Player intercepts the ball
        ;
            move_towards_ball(Player, FutureX, FutureY)  % Move towards the ball
        )
    ;
        format('~w is too tired to move.~n', [Player])
    ).



move_towards_ball(Player, TargetX, TargetY) :-
    player(Team, Player, Position, Stam, PX, PY),
    speed(Stam, Speed),
    move_step(PX, PY, TargetX, TargetY, Speed, NewX, NewY),
    stamina_drain(Position, Drain),
    NewStamina is max(0, Stam - Drain), % Reduce stamina
    retract(player(Team, Player, Position, Stam, _, _)),
    assert(player(Team, Player, Position, NewStamina, NewX, NewY)),
    format('~w moves towards the ball at (~w, ~w).~n', [Player, NewX, NewY]).

% Define stamina drain when moving
stamina_drain(goalkeeper, 1).
stamina_drain(defender, 2).
stamina_drain(midfielder, 3).
stamina_drain(forward, 4).
% Simulate the game loop with halves
simulate_game :-
    game_duration(MaxTime),
    HalfTime is MaxTime // 2,
    simulate_half(1, HalfTime),
    reset_players_ball,
    write('Half-time! Players rest and recover.'), nl,
    log_event(event{type:"half_time"}),
    recover_all_players,
    simulate_half(HalfTime, MaxTime),
    write('Full-time! Game over.'), nl,
    log_event(event{type:"full_time"}),
    display_final_score.

simulate_half(Time, MaxTime) :-
    Time =< MaxTime,  % Continue if within the max time
    update_ball,
    % Get players who can intercept the ball
    players_who_can_intercept(Interceptors),
    % If there are interceptors available
    (Interceptors \= [] ->
        (   % Try to intercept the ball
            member(Player, Interceptors),
            move_to_intercept(Player)  % Move the player to intercept the ball
        )
    ;
        % If no one is in interception range, allow players to move toward the ball
        players_near_ball(MoveCandidates),
        (MoveCandidates \= [] ->
            member(Player, MoveCandidates),
            move_to_intercept(Player)   % Move players toward the ball
        ; true)
    ),

    % If a player has possession, simulate the kick
    % Prevents infinite kicking as well
    ball(_, _, VX, VY, Possession),
    (Possession \= none, VX =:= 0, VY =:= 0 ->
        kick(Possession)
    ; true),

    check_goal,
    recover_all_players,

    % update the game time + continue simulation
    NewTime is Time + 1,
    simulate_half(NewTime, MaxTime).  % Continue with the next time step

simulate_half(Time, MaxTime) :-
    % when max time, finalize game
    Time > MaxTime,
    !.  % Cut to stop further recursion once the game time is over



display_final_score :-
    score(teamA, ScoreA),
    score(teamB, ScoreB),
    format('Final Score: Team A ~w - Team B ~w~n', [ScoreA, ScoreB]).


reset_score :-
    retractall(score(_, _)),
    assertz(score(teamA, 0)),
    assertz(score(teamB, 0)).

% Build current game state as a response dict
build_game_state(Response) :-
    ball(X, Y, VX, VY, Possession),
    findall(_{name: Name, team: Team, x: PX, y: PY},
        player(Team, Name, _, _, PX, PY),
        Players),
    collect_events(Events),
    score(teamA, ScoreA),
    score(teamB, ScoreB),
    Response = _{
        ball: _{x:X, y:Y, vx:VX, vy:VY},
        possession: Possession,
        players: Players,
        events: Events,
        score: _{teamA: ScoreA, teamB: ScoreB}
    }.

% ==========================================
% STRATEGY OPTIMIZER
% ==========================================

% Save complete game state for restoration after optimization
save_game_state(state(Players, Events, BallState, SA, SB, CT, StratA, StratB)) :-
    findall(player(T,N,P,S,X,Y), player(T,N,P,S,X,Y), Players),
    findall(E, game_event(E), Events),
    ball(BX,BY,BVX,BVY,BP),
    BallState = ball(BX,BY,BVX,BVY,BP),
    score(teamA, SA),
    score(teamB, SB),
    (current_time(CT) -> true ; CT = 1),
    team_strategy(teamA, A1,PA1,PI1,DL1,KP1),
    StratA = strategy(A1,PA1,PI1,DL1,KP1),
    team_strategy(teamB, A2,PA2,PI2,DL2,KP2),
    StratB = strategy(A2,PA2,PI2,DL2,KP2).

restore_game_state(state(Players, Events, ball(BX,BY,BVX,BVY,BP), SA, SB, CT,
                         strategy(A1,PA1,PI1,DL1,KP1), strategy(A2,PA2,PI2,DL2,KP2))) :-
    retractall(player(_,_,_,_,_,_)),
    retractall(ball(_,_,_,_,_)),
    retractall(score(_,_)),
    retractall(current_time(_)),
    retractall(team_strategy(_,_,_,_,_,_)),
    retractall(game_event(_)),
    assertz(ball(BX,BY,BVX,BVY,BP)),
    assertz(score(teamA, SA)),
    assertz(score(teamB, SB)),
    assertz(current_time(CT)),
    assertz(team_strategy(teamA, A1,PA1,PI1,DL1,KP1)),
    assertz(team_strategy(teamB, A2,PA2,PI2,DL2,KP2)),
    forall(member(P, Players), assertz(P)),
    forall(member(E, Events), assertz(game_event(E))).

% Run a single silent game with halftime, return ScoreA-ScoreB
run_silent_game(ScoreA-ScoreB) :-
    reset_players_ball,
    reset_score,
    retractall(game_event(_)),
    game_duration(MaxTime),
    HalfTime is MaxTime // 2,
    with_output_to(string(_), (
        simulate_half(1, HalfTime),
        reset_players_ball,
        recover_all_players,
        simulate_half(HalfTime, MaxTime)
    )),
    score(teamA, ScoreA),
    score(teamB, ScoreB).

% Run multiple trials, accumulate goal difference and wins
run_trials(0, _, 0, 0) :- !.
run_trials(N, Team, TotalDiff, TotalWins) :-
    N > 0,
    run_silent_game(SA-SB),
    (Team = teamA -> Diff is SA - SB ; Diff is SB - SA),
    (Diff > 0 -> Win = 1 ; Win = 0),
    N1 is N - 1,
    run_trials(N1, Team, RestDiff, RestWins),
    TotalDiff is Diff + RestDiff,
    TotalWins is Win + RestWins.

% Grid search values for each parameter
param_values([25, 50, 75]).

% Generate parameter combinations via backtracking
generate_params(A, PA, PI, DL, KP) :-
    param_values(Vals),
    member(A, Vals),
    member(PA, Vals),
    member(PI, Vals),
    member(DL, Vals),
    member(KP, Vals).

% Take first N elements from a list
take(_, [], []) :- !.
take(0, _, []) :- !.
take(N, [H|T], [H|R]) :-
    N > 0,
    N1 is N - 1,
    take(N1, T, R).

% Main optimization: grid search over parameter space for a team
% Runs games with target team using each param combo vs opponent at defaults
optimize_team(Team, NumTrials, TopResults) :-
    save_game_state(SavedState),

    % Set opponent to default strategy during optimization
    (Team = teamA -> Opponent = teamB ; Opponent = teamA),
    set_team_strategy(Opponent, 50, 50, 50, 50, 50),

    findall(
        result(AvgDiff, Wins, A, PA, PI, DL, KP),
        (
            generate_params(A, PA, PI, DL, KP),
            set_team_strategy(Team, A, PA, PI, DL, KP),
            run_trials(NumTrials, Team, TotalDiff, Wins),
            AvgDiff is TotalDiff / max(1, NumTrials)
        ),
        AllResults
    ),

    restore_game_state(SavedState),

    % Sort descending by goal difference (keeps duplicates)
    msort(AllResults, SortedAsc),
    reverse(SortedAsc, Sorted),
    take(5, Sorted, TopResults).
