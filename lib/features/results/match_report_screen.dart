// MatchReportScreen: "Match insights" (MatchReport.dc.html), opened from the Win screen.
//
// Top to bottom: what the match was (place, table, turns, minutes), the race chart, six stat tiles
// (rolls, sixes, captures, times captured, average roll against the fair 3.5, the turn of the first
// piece home), the key moments and the smart-move rate. It reads the recorded match from
// `matchResultProvider`, like the Win screen; nothing recorded shows a button back to the lobby.
//
// Bottom bar: home and PLAY AGAIN (the same rules as on the Win screen, including the break ad,
// because both leave the results). The board's "Watch replay" button is not here: a record keeps
// no move log to replay. The back arrow returns to the Win screen without any ad.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/tr.dart';
import '../../core/router/routes.dart';
import '../../core/theme/box_paint.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/backdrops.dart';
import '../../core/widgets/gloss_button.dart';
import '../../core/widgets/lm_box.dart';
import '../../core/widgets/screen_header.dart';
import '../match/match_launcher.dart';
import 'report_model.dart';
import 'result_exit.dart';
import 'result_model.dart';
import 'result_palette.dart';
import 'widgets/no_result.dart';
import 'widgets/race_chart.dart';
import 'widgets/report_panels.dart';
import 'widgets/result_buttons.dart';

class MatchReportScreen extends ConsumerStatefulWidget {
  const MatchReportScreen({super.key});

  @override
  ConsumerState<MatchReportScreen> createState() => _MatchReportScreenState();
}

class _MatchReportScreenState extends ConsumerState<MatchReportScreen> with ResultExit<MatchReportScreen> {
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(matchResultProvider);
    if (result == null) return const NoResultView();
    final model = ReportModel.of(result);
    final record = model.record;
    final next = nextStepFor(record);
    // The board ends with a 34 pt strip (the home-indicator inset); a phone without one keeps room for the lip.
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 14.0);
    return Scaffold(
      backgroundColor: LmColors.deep,
      body: ScreenBackdrop(
        spec: BackdropSpec.screen,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SkyHeader(title: tr('MATCH INSIGHTS'), onBack: _back),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ReportChips(model.chips),
                      const SizedBox(height: 14),
                      RaceChartPanel(model: model),
                      const SizedBox(height: 14),
                      StatsGrid(model.stats),
                      if (model.moments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        MomentsPanel(model.moments),
                      ],
                      if (model.smart != null) ...[
                        const SizedBox(height: 14),
                        SmartMovesPanel(model.smart!),
                      ],
                    ],
                  ),
                ),
              ),
              LmBox(
                gradient: LmGradient([ResultPalette.reportBar.withValues(alpha: 0), ResultPalette.reportBar], stops: const [0, .35]),
                padding: EdgeInsets.fromLTRB(12, 12, 12, bottom),
                child: Row(
                  children: [
                    HomeButton(size: 56, onTap: leaving ? null : () => toLobby(record)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ResultButton(
                        label: nextStepLabel(next),
                        kind: GlossKind.green,
                        fontSize: 18,
                        height: 56,
                        onTap: leaving ? null : () => nextStep(next, record),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
