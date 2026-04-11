:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).

:- consult('game.pl').  

:- http_handler(root(action), handle_action, []).

start_server :-
    http_server(http_dispatch, [port(5000)]).

handle_action(Request) :-
    http_read_json_dict(Request, Dict),
    Action = Dict.get(action),
    process_action(Action, Response),
    reply_json_dict(Response).



% unity sends step so prolog runs: simulate_half(1,1) which will return the ball position, players, possession

% For half time, full time
:- dynamic current_time/1.
current_time(1).

process_action("step", Response) :-
    current_time(T),

    with_output_to(string(_), simulate_half(T,T)),  

    NewT is T + 1,
    retract(current_time(T)),
    assertz(current_time(NewT)),

    % check if halftime/fulltime already
    game_duration(MaxTime),
    HalfTime is MaxTime // 2,

    (NewT =:= HalfTime ->
        log_event(event{type:"half_time"})
    ; true),

    (NewT =:= MaxTime ->
        log_event(event{type:"full_time"})
    ; true),

    % get ball
    ball(X, Y, VX, VY, Possession),

    % get players
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

process_action("reset", Response) :-
    reset_players_ball,
    reset_score,
    retractall(current_time(_)),
    assertz(current_time(1)),
    retractall(game_event(_)),
    build_game_state(Response).



