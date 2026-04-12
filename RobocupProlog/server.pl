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
    process_action(Action, Dict, Response),
    reply_json_dict(Response).



% unity sends step so prolog runs: simulate_half(1,1) which will return the ball position, players, possession

% For half time, full time
:- dynamic current_time/1.
current_time(1).

process_action("step", _Dict, Response) :-
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

process_action("reset", _Dict, Response) :-
    reset_players_ball,
    reset_score,
    retractall(current_time(_)),
    assertz(current_time(1)),
    retractall(game_event(_)),
    build_game_state(Response).

% Set strategy parameters for a team
process_action("set_strategy", Dict, Response) :-
    TeamStr = Dict.get(team),
    atom_string(Team, TeamStr),
    A = Dict.get(aggression),
    PA = Dict.get(passing_accuracy),
    PI = Dict.get(pressing_intensity),
    DL = Dict.get(defensive_line),
    KP = Dict.get(kick_power),
    set_team_strategy(Team, A, PA, PI, DL, KP),
    Response = _{status: "ok"}.

% Get current strategy parameters for both teams
process_action("get_strategy", _Dict, Response) :-
    team_strategy(teamA, A1, PA1, PI1, DL1, KP1),
    team_strategy(teamB, A2, PA2, PI2, DL2, KP2),
    Response = _{
        teamA: _{aggression: A1, passing_accuracy: PA1, pressing_intensity: PI1,
                 defensive_line: DL1, kick_power: KP1},
        teamB: _{aggression: A2, passing_accuracy: PA2, pressing_intensity: PI2,
                 defensive_line: DL2, kick_power: KP2}
    }.

% Run optimization search for a team's best strategy
process_action("optimize", Dict, Response) :-
    TeamStr = Dict.get(team),
    atom_string(Team, TeamStr),
    (get_dict(trials, Dict, NumTrials) -> true ; NumTrials = 1),
    optimize_team(Team, NumTrials, TopResults),
    format_results(TopResults, FormattedResults),
    Response = _{status: "ok", results: FormattedResults}.

format_results([], []).
format_results([result(AvgDiff, Wins, A, PA, PI, DL, KP)|Rest],
               [_{avg_goal_diff: AvgDiff, wins: Wins,
                  aggression: A, passing_accuracy: PA, pressing_intensity: PI,
                  defensive_line: DL, kick_power: KP}|FormattedRest]) :-
    format_results(Rest, FormattedRest).
