// The board geometry the art layer draws on: [Seat], [Board] and [GridPoint].
//
// Why a file of its own: the painter, the piece overlay and the dice tray only
// need the 15 × 15 plan (square coordinates, lanes, yards, stars) from the rules
// engine's public geometry API. One re-export here keeps that dependency in a
// single line, so the art files never reach into the engine package's `src/`.

export 'package:ludo_engine/ludo_engine.dart' show Board, GridPoint, Seat;
