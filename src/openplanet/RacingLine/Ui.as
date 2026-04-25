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
    UI::Text("Current map: " + (g_CurrentMapName.Length > 0 ? g_CurrentMapName : "-"));
    UI::Text("Bundle folder: " + (g_CurrentMapFolderName.Length > 0 ? BundleRootDirectory + "/" + g_CurrentMapFolderName : "-"));

    if (g_AvailableBundleFiles.Length == 0) {
        UI::Text("Bundle: " + g_SelectedBundleFileName);
    } else if (UI::BeginCombo("Bundle", g_SelectedBundleFileName)) {
        for (uint i = 0; i < g_AvailableBundleFiles.Length; i++) {
            bool isSelected = int(i) == g_SelectedBundleIndex;
            if (UI::Selectable(g_AvailableBundleFiles[i], isSelected)) {
                g_SelectedBundleFileName = g_AvailableBundleFiles[i];
                g_SelectedBundleIndex = int(i);
                ReloadBundle();
            }
        }
        UI::EndCombo();
    }

    UI::Text("Bundle path: " + (g_BundlePath.Length > 0 ? g_BundlePath : BuildCurrentMapBundlePath(g_SelectedBundleFileName)));
    if (UI::Button("Refresh bundles")) {
        RefreshBundleFiles();
    }
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
    UI::Text("Current map: " + (g_CurrentMapName.Length > 0 ? g_CurrentMapName : "-"));
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
