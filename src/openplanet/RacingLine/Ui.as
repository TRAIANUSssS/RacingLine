void RenderWindow() {
    if (!g_ShowWindow) {
        return;
    }

    UI::SetNextWindowSize(420, 320, UI::Cond::FirstUseEver);
    if (UI::Begin("RacingLine", g_ShowWindow)) {
        RenderDataSection();
        UI::Separator();
        RenderStatusSection();
        UI::Separator();
        RenderInfoSection();
        UI::Separator();
        RenderToggleSection();
    }
    UI::End();
}

void RenderDataSection() {
    UI::Text("Data");
    g_BundlePath = UI::InputText("Bundle path", g_BundlePath);
    if (UI::Button("Reload")) {
        ReloadBundle();
    }
}

void RenderStatusSection() {
    UI::Text("Status");
    if (g_BundleLoaded) {
        UI::Text("Loaded");
    } else {
        UI::Text("Failed or not loaded");
    }

    if (g_LastError.Length > 0) {
        UI::TextWrapped(g_LastError);
    } else {
        UI::TextWrapped("No errors.");
    }
}

void RenderInfoSection() {
    UI::Text("Info");
    if (g_Bundle is null) {
        UI::Text("Map: -");
        UI::Text("Mine run: -");
        UI::Text("Center points: 0");
        UI::Text("Mine points: 0");
        UI::Text("Problem zones: 0");
        return;
    }

    UI::Text("Map: " + (g_Bundle.mapName.Length > 0 ? g_Bundle.mapName : "-"));
    UI::Text("Mine run: " + (g_Bundle.mineRunName.Length > 0 ? g_Bundle.mineRunName : "-"));
    UI::Text("Center points: " + g_Bundle.centerLine.Length);
    UI::Text("Mine points: " + g_Bundle.mineLine.Length);
    UI::Text("Problem zones: " + g_Bundle.problemZones.Length);
    UI::Text("Projected center segments: " + g_LastProjectedCenterSegments);
    UI::Text("Skipped center segments: " + g_LastSkippedCenterSegments);
    UI::Text("Projected mine segments: " + g_LastProjectedMineSegments);
    UI::Text("Skipped mine segments: " + g_LastSkippedMineSegments);
    UI::Text("Projected problem zones: " + g_LastProjectedProblemZones);
    UI::Text("Skipped problem zones: " + g_LastSkippedProblemZones);
    UI::Text("Viewport cameras: " + g_LastCameraCount);
}

void RenderToggleSection() {
    UI::Text("Toggles");
    g_ShowCenter = UI::Checkbox("Show Center", g_ShowCenter);
    g_ShowMine = UI::Checkbox("Show Mine", g_ShowMine);
    g_ShowProblemZones = UI::Checkbox("Show Problem Zones", g_ShowProblemZones);
}
