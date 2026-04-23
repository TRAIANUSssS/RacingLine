uint g_LastProjectedSegments = 0;
uint g_LastSkippedSegments = 0;
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
    g_LastProjectedSegments = 0;
    g_LastSkippedSegments = 0;

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
            g_LastSkippedSegments++;
            hasOpenSubPath = false;
            continue;
        }

        g_LastProjectedSegments++;
        if (!hasOpenSubPath) {
            nvg::MoveTo(a);
            hasOpenSubPath = true;
        }
        nvg::LineTo(b);
    }

    if (g_LastProjectedSegments > 0) {
        nvg::Stroke();
    }
}

void RenderWorldOverlay() {
    if (!g_BundleLoaded) {
        return;
    }

    if (g_Bundle is null) {
        return;
    }

    if (!g_ShowCenter) {
        return;
    }

    DrawCenterLine();
}
