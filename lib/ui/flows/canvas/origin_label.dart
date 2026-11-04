import 'package:flutter/material.dart' hide Flow;

import '../../../engine/flows/input_origin.dart';
import '../../../engine/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

/// How a step shows where an input comes from: `← Login`, `env`, `🔑 session`
/// or `⚠ no source`.
String originLabel(BuildContext context, InputOrigin origin, Flow flow, Map<String, Endpoint> endpoints) =>
    switch (origin) {
      FromStep(:final stepIndex) => context.l10n.canvasOriginStep(
          endpoints[flow.steps[stepIndex].endpointId]?.name ?? '${stepIndex + 1}',
        ),
      FromEnvironment() => context.l10n.canvasOriginEnv,
      FromSession() => context.l10n.canvasOriginSession,
      Missing() => context.l10n.canvasOriginMissing,
    };

/// The color of [originLabel]: a missing source stands out, the session is
/// marked like its tokens, the rest stays quiet.
Color originColor(InputOrigin origin) => switch (origin) {
      Missing() => AppColors.error,
      FromSession() => AppColors.warning,
      FromStep() || FromEnvironment() => AppColors.onSurfaceVariant,
    };
