field_size(200, 120).
goal_width(14).
game_duration(200). % Total game time in ticks 

% Ball state: ball(X, Y, VX, VY, Possession).
:- dynamic ball/5.

% Edit: start ball at player6A
ball(100, 60, 0, 0, player_6A).

% Ensure the ball stays within bounds
adjust_position(X, Y, NewX, NewY) :-
    (Y < 0 -> NewY = 0;
    Y > 120 -> NewY = 120;
    NewY = Y),
    field_size(MaxX, _),
    NewX is min(max(X, 0), MaxX).

% Update ball position
% Case 1: Ball is stopped → do nothing
update_ball :-
    ball(_, _, VX, VY, _),
    VX =:= 0,
    VY =:= 0,
    !.

% Case 2: Ball is moving → update
update_ball :-
    retract(ball(X, Y, VX, VY, Possession)),

    TempX is X + VX,
    TempY is Y + VY,

    adjust_position(TempX, TempY, NewX, NewY),

    TempVX is VX * 0.9,
    TempVY is VY * 0.9,

    field_size(MaxX, MaxY),

    % BOUNCE off X walls (negate VX), instead of zeroing it
    ( (NewX =< 0.01 ; NewX >= MaxX - 0.01) -> NewVX is -TempVX ; NewVX = TempVX ),
    ( (NewY =< 0.01 ; NewY >= MaxY - 0.01) -> NewVY = 0         ; NewVY = TempVY ),

    ( (abs(NewVX) < 0.1, abs(NewVY) < 0.1) ->
        FinalVX = 0, FinalVY = 0, NewPossession = none
    ;
        FinalVX = NewVX, FinalVY = NewVY, NewPossession = Possession
    ),

    assertz(ball(NewX, NewY, FinalVX, FinalVY, NewPossession)),
    format('Ball moved to: (~w, ~w)~n', [NewX, NewY]),
    check_goal.


kick_direction(Team, Direction) :-
    % Team 'A' kicks toward right (up front) and 'B' toward left
    (Team = teamA -> Direction = right; Direction = left).

% Main kick action
kick(Player) :-
    player(Team,Player,Position,Stamina,_,_),
    % Determine the direction of the kick
    kick_direction(Team, Direction),
    % Set the ball velocity
    (Direction = left -> NewVX is -5-Stamina/10; NewVX is 5+Stamina/10),  % Left means negative X velocity (towards the opponent goal)
    (Position = midfielder->random_between(-10,10,R); random_between(-20,20,R)),
	NewVY is R,  % Keep Y velocity constant (no vertical movement)
	retract(ball(X, Y, _,_,_)),
    assertz(ball(X, Y, NewVX, NewVY, none)),
    format('Player ~w kicks the ball ~w as a ~w~n', [Player, Direction,Position]),
    update_ball. % Update the ball’s position after the kick



% Player definitions
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

% Define initial positions for players
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

% Players who can intercept the ball
intercept_radius(forward, 2).
intercept_radius(midfielder, 3).
intercept_radius(defender, 5).

distance(X1, Y1, X2, Y2, Dist) :-
    DX is X2 - X1,
    DY is Y2 - Y1,
    Dist is sqrt(DX*DX + DY*DY).

% Goal detection with goalkeeper save attempt and correct goal assignment
check_goal :- 
    ball(BallX, BallY, _, _, _),
    field_size(FieldLength, FieldWidth),
    goal_width(GoalWidth),
    
    % Check if the ball is in the scoring range for Team A (right side of the field)
    ( BallX >= FieldLength, abs(BallY - (FieldWidth / 2)) =< (GoalWidth / 2) -> 
        % Attempt save for Team B goalkeeper
        player(teamB, Goalkeeper, goalkeeper, _, GKX, GKY),
        distance(GKX, GKY, BallX, BallY, Dist),
        save_radius(Radius),
        (Dist =< Radius -> 
            attempt_save(Goalkeeper), 
            write('Save attempt by Team B goalkeeper! No goal.~n')
        ; 
           reset_players_ball, write('Goal scored by Team A!'), nl, update_score(teamA) 
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
           reset_players_ball, write('Goal scored by Team B!'), nl, update_score(teamB)
        );
      true
    ).

% Define player speed based on stamina (simple linear scaling)
speed(Stamina, Speed) :-
    Speed is 15+Stamina / 10. % Example scaling factor: 10 stamina = 1 speed unit.

% Define how far the player moves in one step toward the ball (proportional to speed)
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


% Reset players and ball
reset_players_ball :-
    retract(ball(_,_,_,_,_)),
    assertz(ball(100, 60, 0, 0, none)),
    forall(player(Team, Player, Pos, Stam, _, _),
        (init_pos(Team, Player, InitX, InitY),
         retract(player(Team, Player, Pos, Stam, _, _)),
         assertz(player(Team, Player, Pos, 80, InitX, InitY)))).

% Goalkeeper save
save_radius(10).  % Goalkeeper can save the ball if it's within 8 units

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

players_who_can_intercept(Players) :-
    ball(BX, BY, VX, VY, _),
    FutureX is BX + VX,
    FutureY is BY + VY,
    findall(Player, (
        player(_, Player, Position, _, PX, PY),
        (Position = defender; Position = midfielder;Position=forward),
        intercept_radius(Position, Radius),
        distance(PX, PY, FutureX, FutureY, Dist),
        Dist =< Radius
    ), Players).

% Check if any player is within range of the ball
players_near_ball(Players) :-
    ball(BX, BY, _, _, _),
    findall(Player, (
        player(_, Player, _, _, PX, PY),
        distance(PX, PY, BX, BY, Dist),
        Dist =< 50  
    ), Players).

% Players who can intercept the ball and update possession
intercept(Player) :-
    player(_, Player, Position, _, PX, PY),   % Get player position
    ball(BX, BY, VX, VY, _),                    % Get current ball position
    FutureX is BX + VX,                         % Predict ball's future X position
    FutureY is BY + VY,                         % Predict ball's future Y position
    intercept_radius(Position, Radius),         % Get player's interception radius
    distance(PX, PY, FutureX, FutureY, Dist),  % Calculate distance to ball's future position
    Dist =< Radius,                             % Check if player is within interception range
    retract(ball(BX, BY, VX, VY, _)),
    assertz(ball(PX, PY, 0, 0, Player)),
    format('~w intercepted the ball!~n', [Player]).

% Move to intercept the ball if possible
move_to_intercept(Player) :- 
    player(_, Player, Position, Stam, PX, PY),
    (Stam > 0 -> 
        ball(X, Y, VX, VY, _),
        FutureX is X + VX,
        FutureY is Y + VY,
        intercept_radius(Position, Radius),
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

% Define stamina drain when moving (simple example, it could be different based on position)
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
    recover_all_players,
    simulate_half(HalfTime, MaxTime),
    write('Full-time! Game over.'), nl,
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
    % Check if a goal is scored
    check_goal,
    % Recover stamina for all players
    recover_all_players,
    % Update the game time and continue simulation
    NewTime is Time + 1,
    simulate_half(NewTime, MaxTime).  % Continue with the next time step

simulate_half(Time, MaxTime) :-
    % If max time is reached, stop and finalize the game
    Time > MaxTime,
    !.  % Cut to stop further recursion once the game time is over


% Display final score
display_final_score :-
    score(teamA, ScoreA),
    score(teamB, ScoreB),
    format('Final Score: Team A ~w - Team B ~w~n', [ScoreA, ScoreB]).


