uint g_LastProjectedCenterSegments = 0;
uint g_LastSkippedCenterSegments = 0;
uint g_LastProjectedMineSegments = 0;
uint g_LastSkippedMineSegments = 0;
uint g_LastProjectedProblemZones = 0;
uint g_LastSkippedProblemZones = 0;
uint g_LastCameraCount = 0;

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

void DrawCenterLine() {
    g_LastProjectedCenterSegments = 0;
    g_LastSkippedCenterSegments = 0;

    if (g_Bundle is null || g_Bundle.centerLine.Length < 2) {
        return;
    }

    nvg::BeginPath();
    nvg::StrokeWidth(CenterLineWidth);
    nvg::StrokeColor(CenterLineColor);

    bool hasOpenSubPath = false;
    for (uint i = 1; i < g_Bundle.centerLine.Length; i++) {
        CenterPoint@ prev = g_Bundle.centerLine[i - 1];
        CenterPoint@ curr = g_Bundle.centerLine[i];
        if (prev is null || curr is null) {
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

void DrawMineLine() {
    g_LastProjectedMineSegments = 0;
    g_LastSkippedMineSegments = 0;

    if (g_Bundle is null || g_Bundle.mineLine.Length < 2) {
        return;
    }

    nvg::BeginPath();
    nvg::StrokeWidth(MineLineWidth);
    nvg::StrokeColor(MineLineColor);

    bool hasOpenSubPath = false;
    for (uint i = 1; i < g_Bundle.mineLine.Length; i++) {
        MinePoint@ prev = g_Bundle.mineLine[i - 1];
        MinePoint@ curr = g_Bundle.mineLine[i];
        if (prev is null || curr is null) {
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

void DrawProblemZones() {
    g_LastProjectedProblemZones = 0;
    g_LastSkippedProblemZones = 0;

    if (g_Bundle is null || g_Bundle.problemZones.Length == 0) {
        return;
    }

    for (uint i = 0; i < g_Bundle.problemZones.Length; i++) {
        ProblemZone@ zone = g_Bundle.problemZones[i];
        if (zone is null) {
            continue;
        }

        vec2 screenPos;
        if (!ProjectWorldPoint(zone.pos, screenPos)) {
            g_LastSkippedProblemZones++;
            continue;
        }

        g_LastProjectedProblemZones++;

        nvg::BeginPath();
        nvg::Circle(screenPos, ProblemZoneMarkerSize);
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
    g_LastProjectedProblemZones = 0;
    g_LastSkippedProblemZones = 0;

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

    if (g_ShowProblemZones) {
        DrawProblemZones();
    }
}
