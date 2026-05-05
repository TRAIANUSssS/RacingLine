uint g_LastProjectedCenterSegments = 0;
uint g_LastSkippedCenterSegments = 0;
uint g_LastProjectedMineSegments = 0;
uint g_LastSkippedMineSegments = 0;
uint g_LastProjectedOtherRunSegments = 0;
uint g_LastSkippedOtherRunSegments = 0;
uint g_LastProjectedProblemZones = 0;
uint g_LastSkippedProblemZones = 0;
uint g_LastCameraCount = 0;
bool g_LastRenderReferenceAvailable = false;
vec3 g_LastRenderReferencePos = vec3();
bool g_RouteWindowAvailable = false;
int g_RenderAnchorIndex = -1;
int g_VisibleIndexStart = 0;
int g_VisibleIndexEnd = -1;
float g_LastRouteAnchorDistance = 0.0f;

void ResetRouteWindowState() {
    g_RouteWindowAvailable = false;
    g_RenderAnchorIndex = -1;
    g_VisibleIndexStart = 0;
    g_VisibleIndexEnd = -1;
    g_LastRouteAnchorDistance = 0.0f;
}

bool ProjectWorldPoint(const vec3 &in worldPos, vec2 &out screenPos) {
    CGameApp@ app = GetApp();
    if (app is null || app.Viewport is null) {
        return false;
    }

    g_LastCameraCount = app.Viewport.Cameras.Length;

    CHmsCamera@ camera = Camera::GetCurrent();
    if (camera is null) {
        return false;
    }

    if (Camera::IsBehind(worldPos)) {
        return false;
    }

    vec3 projected = Camera::ToScreen(worldPos);
    if (projected.z > 0.0f || Math::IsNaN(projected.x) || Math::IsNaN(projected.y)) {
        return false;
    }

    screenPos = projected.xy;
    return true;
}

bool TryGetCurrentCarPosition(vec3 &out carPos) {
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null || app.CurrentPlayground is null) {
        return false;
    }

    CSmArenaClient@ playground = cast<CSmArenaClient>(app.CurrentPlayground);
    if (playground is null || playground.GameTerminals.Length == 0 || playground.GameTerminals[0] is null) {
        return false;
    }

    CSmPlayer@ player = cast<CSmPlayer>(playground.GameTerminals[0].ControlledPlayer);
    if (player is null || player.ScriptAPI is null) {
        return false;
    }

    CSmScriptPlayer@ scriptPlayer = cast<CSmScriptPlayer>(player.ScriptAPI);
    if (scriptPlayer is null || !scriptPlayer.IsEntityStateAvailable) {
        return false;
    }

    carPos = scriptPlayer.Position;
    return true;
}

float DistanceSquared(const vec3 &in a, const vec3 &in b) {
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    float dz = a.z - b.z;
    return dx * dx + dy * dy + dz * dz;
}

bool IsPointInsideRenderDistance(const vec3 &in worldPos) {
    if (g_ShowFullTrajectory || !g_LastRenderReferenceAvailable) {
        return true;
    }

    float distance = Math::Max(g_RenderDistance, 0.0f);
    return DistanceSquared(worldPos, g_LastRenderReferencePos) <= distance * distance;
}

bool IsSegmentInsideRenderDistance(const vec3 &in a, const vec3 &in b) {
    return IsPointInsideRenderDistance(a) || IsPointInsideRenderDistance(b);
}

float DistanceSquared3D(const vec3 &in a, const vec3 &in b) {
    return DistanceSquared(a, b);
}

int ClampInt(int value, int minValue, int maxValue) {
    if (value < minValue) {
        return minValue;
    }
    if (value > maxValue) {
        return maxValue;
    }
    return value;
}

int MaxInt(int a, int b) {
    return a > b ? a : b;
}

float CenterSegmentLength(uint index) {
    if (g_Bundle is null || index == 0 || index >= g_Bundle.centerLine.Length) {
        return 0.0f;
    }

    CenterPoint@ prev = g_Bundle.centerLine[index - 1];
    CenterPoint@ curr = g_Bundle.centerLine[index];
    if (prev is null || curr is null) {
        return 0.0f;
    }

    return Math::Sqrt(DistanceSquared3D(prev.pos, curr.pos));
}

int FindNearestCenterIndex(const vec3 &in carPos, int startIndex, int endIndex, float &out bestDistanceSquared) {
    bestDistanceSquared = 0.0f;
    if (g_Bundle is null || g_Bundle.centerLine.Length == 0) {
        return -1;
    }

    int lastIndex = int(g_Bundle.centerLine.Length) - 1;
    startIndex = ClampInt(startIndex, 0, lastIndex);
    endIndex = ClampInt(endIndex, 0, lastIndex);
    if (endIndex < startIndex) {
        return -1;
    }

    int bestIndex = -1;
    for (int i = startIndex; i <= endIndex; i++) {
        CenterPoint@ point = g_Bundle.centerLine[uint(i)];
        if (point is null) {
            continue;
        }

        float distanceSquared = DistanceSquared3D(carPos, point.pos);
        if (bestIndex < 0 || distanceSquared < bestDistanceSquared) {
            bestIndex = i;
            bestDistanceSquared = distanceSquared;
        }
    }

    return bestIndex;
}

void UpdateRouteWindow(const vec3 &in carPos) {
    g_RouteWindowAvailable = false;
    g_VisibleIndexStart = 0;
    g_VisibleIndexEnd = -1;

    if (!g_UseRouteWindow || g_ShowFullTrajectory || g_Bundle is null || g_Bundle.centerLine.Length < 2) {
        return;
    }

    int lastIndex = int(g_Bundle.centerLine.Length) - 1;
    int anchorIndex = -1;
    float bestDistanceSquared = 0.0f;
    bool needsGlobalReacquire = g_RenderAnchorIndex < 0 || g_RenderAnchorIndex > lastIndex;

    if (!needsGlobalReacquire) {
        int localStart = g_RenderAnchorIndex - MaxInt(g_RouteAnchorBackSearchPoints, 0);
        int localEnd = g_RenderAnchorIndex + MaxInt(g_RouteAnchorForwardSearchPoints, 0);
        anchorIndex = FindNearestCenterIndex(carPos, localStart, localEnd, bestDistanceSquared);
        float reacquireDistance = Math::Max(g_RouteReacquireDistance, 1.0f);
        if (anchorIndex < 0 || bestDistanceSquared > reacquireDistance * reacquireDistance) {
            needsGlobalReacquire = true;
        }
    }

    if (needsGlobalReacquire) {
        anchorIndex = FindNearestCenterIndex(carPos, 0, lastIndex, bestDistanceSquared);
    }

    if (anchorIndex < 0) {
        return;
    }

    g_RenderAnchorIndex = anchorIndex;
    g_LastRouteAnchorDistance = Math::Sqrt(bestDistanceSquared);

    int startIndex = anchorIndex;
    float accumulated = 0.0f;
    float lookbehind = Math::Max(g_RouteLookbehindDistance, 0.0f);
    while (startIndex > 0 && accumulated < lookbehind) {
        accumulated += CenterSegmentLength(uint(startIndex));
        startIndex--;
    }

    int endIndex = anchorIndex;
    accumulated = 0.0f;
    float lookahead = Math::Max(g_RouteLookaheadDistance, 0.0f);
    while (endIndex < lastIndex && accumulated < lookahead) {
        endIndex++;
        accumulated += CenterSegmentLength(uint(endIndex));
    }

    g_VisibleIndexStart = startIndex;
    g_VisibleIndexEnd = endIndex;
    g_RouteWindowAvailable = g_VisibleIndexEnd > g_VisibleIndexStart;
}

bool IsSegmentInsideRouteWindow(uint segmentEndIndex) {
    if (!g_RouteWindowAvailable) {
        return true;
    }

    int startIndex = int(segmentEndIndex) - 1;
    int endIndex = int(segmentEndIndex);
    return startIndex >= g_VisibleIndexStart && endIndex <= g_VisibleIndexEnd;
}

bool IsProblemZoneInsideRouteWindow(ProblemZone@ zone) {
    if (!g_RouteWindowAvailable || zone is null) {
        return true;
    }

    if (zone.index >= 0) {
        return zone.index >= g_VisibleIndexStart && zone.index <= g_VisibleIndexEnd;
    }

    return IsPointInsideRenderDistance(zone.pos);
}

void DrawCenterLine() {
    g_LastProjectedCenterSegments = 0;
    g_LastSkippedCenterSegments = 0;

    if (g_Bundle is null || g_Bundle.centerLine.Length < 2) {
        return;
    }

    if (g_ColorCenterBySpeedDelta && g_Bundle.analysisPoints.Length >= g_Bundle.centerLine.Length) {
        DrawSpeedDeltaCenterLine();
        return;
    }

    nvg::BeginPath();
    nvg::StrokeWidth(g_CenterLineWidth);
    nvg::StrokeColor(CenterLineColor);

    bool hasOpenSubPath = false;
    for (uint i = 1; i < g_Bundle.centerLine.Length; i++) {
        CenterPoint@ prev = g_Bundle.centerLine[i - 1];
        CenterPoint@ curr = g_Bundle.centerLine[i];
        if (prev is null || curr is null) {
            hasOpenSubPath = false;
            continue;
        }

        if (!IsSegmentInsideRouteWindow(i) || (!g_RouteWindowAvailable && !IsSegmentInsideRenderDistance(prev.pos, curr.pos))) {
            g_LastSkippedCenterSegments++;
            hasOpenSubPath = false;
            continue;
        }

        vec2 a;
        vec2 b;
        if (!ProjectWorldPoint(prev.pos, a) || !ProjectWorldPoint(curr.pos, b)) {
            g_LastSkippedCenterSegments++;
            hasOpenSubPath = false;
            continue;
        }

        g_LastProjectedCenterSegments++;
        if (!hasOpenSubPath) {
            nvg::MoveTo(a);
            hasOpenSubPath = true;
        }
        nvg::LineTo(b);
    }

    if (g_LastProjectedCenterSegments > 0) {
        nvg::Stroke();
    }
}

void DrawSpeedDeltaCenterLine() {
    float minDelta = 0.0f;
    float maxDelta = 0.0f;
    bool hasDelta = false;

    for (uint i = 0; i < g_Bundle.analysisPoints.Length; i++) {
        AnalysisPoint@ point = g_Bundle.analysisPoints[i];
        if (point is null) {
            continue;
        }

        if (!hasDelta) {
            minDelta = point.speedDelta;
            maxDelta = point.speedDelta;
            hasDelta = true;
        } else {
            minDelta = Math::Min(minDelta, point.speedDelta);
            maxDelta = Math::Max(maxDelta, point.speedDelta);
        }
    }

    if (!hasDelta) {
        return;
    }

    for (uint i = 1; i < g_Bundle.centerLine.Length; i++) {
        CenterPoint@ prev = g_Bundle.centerLine[i - 1];
        CenterPoint@ curr = g_Bundle.centerLine[i];
        if (prev is null || curr is null) {
            continue;
        }

        if (!IsSegmentInsideRouteWindow(i) || (!g_RouteWindowAvailable && !IsSegmentInsideRenderDistance(prev.pos, curr.pos))) {
            g_LastSkippedCenterSegments++;
            continue;
        }

        vec2 a;
        vec2 b;
        if (!ProjectWorldPoint(prev.pos, a) || !ProjectWorldPoint(curr.pos, b)) {
            g_LastSkippedCenterSegments++;
            continue;
        }

        AnalysisPoint@ prevAnalysis = g_Bundle.analysisPoints[i - 1];
        AnalysisPoint@ currAnalysis = g_Bundle.analysisPoints[i];
        float segmentDelta = 0.0f;
        if (prevAnalysis !is null && currAnalysis !is null) {
            segmentDelta = (prevAnalysis.speedDelta + currAnalysis.speedDelta) * 0.5f;
        } else if (currAnalysis !is null) {
            segmentDelta = currAnalysis.speedDelta;
        }

        nvg::BeginPath();
        nvg::MoveTo(a);
        nvg::LineTo(b);
        nvg::StrokeWidth(g_CenterLineWidth);
        nvg::StrokeColor(SpeedDeltaColor(segmentDelta, minDelta, maxDelta));
        nvg::Stroke();
        g_LastProjectedCenterSegments++;
    }
}

vec4 SpeedDeltaColor(float delta, float minDelta, float maxDelta) {
    if (maxDelta <= minDelta) {
        return CenterLineColor;
    }

    float t = (delta - minDelta) / (maxDelta - minDelta);
    if (t < 0.0f) {
        t = 0.0f;
    } else if (t > 1.0f) {
        t = 1.0f;
    }

    return vec4(
        SpeedDeltaNegativeColor.x + (SpeedDeltaPositiveColor.x - SpeedDeltaNegativeColor.x) * t,
        SpeedDeltaNegativeColor.y + (SpeedDeltaPositiveColor.y - SpeedDeltaNegativeColor.y) * t,
        SpeedDeltaNegativeColor.z + (SpeedDeltaPositiveColor.z - SpeedDeltaNegativeColor.z) * t,
        SpeedDeltaNegativeColor.w + (SpeedDeltaPositiveColor.w - SpeedDeltaNegativeColor.w) * t
    );
}

void DrawMineLine() {
    g_LastProjectedMineSegments = 0;
    g_LastSkippedMineSegments = 0;

    if (g_Bundle is null || g_Bundle.mineLine.Length < 2) {
        return;
    }

    nvg::BeginPath();
    nvg::StrokeWidth(g_MineLineWidth);
    nvg::StrokeColor(MineLineColor);

    bool hasOpenSubPath = false;
    for (uint i = 1; i < g_Bundle.mineLine.Length; i++) {
        MinePoint@ prev = g_Bundle.mineLine[i - 1];
        MinePoint@ curr = g_Bundle.mineLine[i];
        if (prev is null || curr is null) {
            hasOpenSubPath = false;
            continue;
        }

        if (!IsSegmentInsideRouteWindow(i) || (!g_RouteWindowAvailable && !IsSegmentInsideRenderDistance(prev.pos, curr.pos))) {
            g_LastSkippedMineSegments++;
            hasOpenSubPath = false;
            continue;
        }

        vec2 a;
        vec2 b;
        if (!ProjectWorldPoint(prev.pos, a) || !ProjectWorldPoint(curr.pos, b)) {
            g_LastSkippedMineSegments++;
            hasOpenSubPath = false;
            continue;
        }

        g_LastProjectedMineSegments++;
        if (!hasOpenSubPath) {
            nvg::MoveTo(a);
            hasOpenSubPath = true;
        }
        nvg::LineTo(b);
    }

    if (g_LastProjectedMineSegments > 0) {
        nvg::Stroke();
    }
}

void DrawOtherRuns() {
    g_LastProjectedOtherRunSegments = 0;
    g_LastSkippedOtherRunSegments = 0;

    if (g_Bundle is null || g_Bundle.runs.Length == 0) {
        return;
    }

    nvg::StrokeWidth(g_OtherRunLineWidth);
    nvg::StrokeColor(OtherRunLineColor);

    for (uint runIndex = 0; runIndex < g_Bundle.runs.Length; runIndex++) {
        RunInfo@ run = g_Bundle.runs[runIndex];
        if (run is null || run.line.Length < 2 || IsMineRun(run)) {
            continue;
        }

        nvg::BeginPath();
        bool hasOpenSubPath = false;
        uint runProjectedSegments = 0;

        for (uint i = 1; i < run.line.Length; i++) {
            RunLinePoint@ prev = run.line[i - 1];
            RunLinePoint@ curr = run.line[i];
            if (prev is null || curr is null) {
                hasOpenSubPath = false;
                continue;
            }

            if (!IsSegmentInsideRouteWindow(i) || (!g_RouteWindowAvailable && !IsSegmentInsideRenderDistance(prev.pos, curr.pos))) {
                g_LastSkippedOtherRunSegments++;
                hasOpenSubPath = false;
                continue;
            }

            vec2 a;
            vec2 b;
            if (!ProjectWorldPoint(prev.pos, a) || !ProjectWorldPoint(curr.pos, b)) {
                g_LastSkippedOtherRunSegments++;
                hasOpenSubPath = false;
                continue;
            }

            g_LastProjectedOtherRunSegments++;
            runProjectedSegments++;
            if (!hasOpenSubPath) {
                nvg::MoveTo(a);
                hasOpenSubPath = true;
            }
            nvg::LineTo(b);
        }

        if (runProjectedSegments > 0) {
            nvg::Stroke();
        }
    }
}

bool IsMineRun(RunInfo@ run) {
    if (run is null || g_Bundle is null || g_Bundle.mineRunName.Length == 0) {
        return false;
    }

    return run.name == g_Bundle.mineRunName;
}

void DrawProblemZones() {
    g_LastProjectedProblemZones = 0;
    g_LastSkippedProblemZones = 0;

    if (g_Bundle is null || g_Bundle.problemZones.Length == 0) {
        return;
    }

    uint visibleLimit = Math::Min(uint(MaxInt(g_MaxVisibleProblemZones, 0)), g_Bundle.problemZones.Length);
    uint renderedCount = 0;
    for (uint i = 0; i < g_Bundle.problemZones.Length; i++) {
        if (renderedCount >= visibleLimit) {
            break;
        }

        ProblemZone@ zone = g_Bundle.problemZones[i];
        if (zone is null) {
            continue;
        }

        if (!IsProblemZoneInsideRouteWindow(zone) || (!g_RouteWindowAvailable && !IsPointInsideRenderDistance(zone.pos))) {
            g_LastSkippedProblemZones++;
            continue;
        }

        vec2 screenPos;
        if (!ProjectWorldPoint(zone.pos, screenPos)) {
            g_LastSkippedProblemZones++;
            continue;
        }

        g_LastProjectedProblemZones++;
        renderedCount++;

        nvg::BeginPath();
        nvg::Circle(screenPos, g_ProblemZoneMarkerSize);
        nvg::FillColor(ProblemZoneColor);
        nvg::Fill();
        nvg::StrokeWidth(2.0f);
        nvg::StrokeColor(vec4(1.0f, 1.0f, 1.0f, 0.9f));
        nvg::Stroke();
    }
}

void RenderWorldOverlay() {
    g_LastProjectedCenterSegments = 0;
    g_LastSkippedCenterSegments = 0;
    g_LastProjectedMineSegments = 0;
    g_LastSkippedMineSegments = 0;
    g_LastProjectedOtherRunSegments = 0;
    g_LastSkippedOtherRunSegments = 0;
    g_LastProjectedProblemZones = 0;
    g_LastSkippedProblemZones = 0;
    g_LastRenderReferenceAvailable = g_ShowFullTrajectory ? false : TryGetCurrentCarPosition(g_LastRenderReferencePos);
    if (g_LastRenderReferenceAvailable) {
        UpdateRouteWindow(g_LastRenderReferencePos);
    } else {
        g_RouteWindowAvailable = false;
    }

    if (!g_BundleLoaded) {
        return;
    }

    if (g_Bundle is null) {
        return;
    }

    if (g_ShowCenter) {
        DrawCenterLine();
    }

    if (g_ShowMine) {
        DrawMineLine();
    }

    if (g_ShowOtherRuns) {
        DrawOtherRuns();
    }

    if (g_ShowProblemZones) {
        DrawProblemZones();
    }
}
