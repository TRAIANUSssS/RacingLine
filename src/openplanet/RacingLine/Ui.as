void RenderWindow() {
    if (!g_ShowWindow) {
        return;
    }

    UI::SetNextWindowSize(420, 320, UI::Cond::FirstUseEver);
    if (UI::Begin("RacingLine", g_ShowWindow)) {
        RenderStatusSection();
        UI::Separator();
        RenderDataSection();
        UI::Separator();
        RenderPipelineSection();
        UI::Separator();
        RenderToggleSection();
        UI::Separator();
        RenderInfoSection();
    }
    UI::End();
}

void RenderDataSection() {
    AutoRefreshBundleFiles();

    UI::Text("Data");
    UI::Text("Current map: " + (g_CurrentMapName.Length > 0 ? g_CurrentMapName : "-"));
    UI::Text("Current user: " + (g_CurrentUserName.Length > 0 ? g_CurrentUserName : "-"));
    UI::Text("Current login: " + (g_CurrentUserLogin.Length > 0 ? g_CurrentUserLogin : "-"));
    UI::Text("Bundle folder: " + (g_CurrentMapFolderName.Length > 0 ? BundleRootDirectory + "/" + g_CurrentMapFolderName : "-"));

    if (g_AvailableBundleFiles.Length == 0) {
        UI::Text("Bundle: " + GetSelectedBundleLabel());
    } else if (UI::BeginCombo("Bundle", GetSelectedBundleLabel())) {
        for (uint i = 0; i < g_AvailableBundleFiles.Length; i++) {
            bool isSelected = int(i) == g_SelectedBundleIndex;
            if (UI::Selectable(g_AvailableBundleLabels[i] + "##" + g_AvailableBundleFiles[i], isSelected)) {
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

void RenderPipelineSection() {
    UI::Text("Pipeline");
    UpdatePipelineCommand();

    string previousRoot = g_PipelineProjectRoot;
    int previousRangeFrom = g_PipelineRangeFrom;
    int previousRangeTo = g_PipelineRangeTo;
    string previousReplayDir = g_PipelineReplayInputDir;
    bool previousIncludeMineReplay = g_PipelineIncludeMineReplay;

    g_PipelineProjectRoot = UI::InputText("Project root", g_PipelineProjectRoot);
    g_PipelineRangeFrom = UI::InputInt("Rank from", g_PipelineRangeFrom);
    g_PipelineRangeTo = UI::InputInt("Rank to", g_PipelineRangeTo);
    g_PipelineReplayInputDir = UI::InputText("Replay dir", g_PipelineReplayInputDir);
    g_PipelineIncludeMineReplay = UI::Checkbox("Use mine replay", g_PipelineIncludeMineReplay);
    NormalizePipelineRange();

    if (previousRoot != g_PipelineProjectRoot || previousRangeFrom != g_PipelineRangeFrom || previousRangeTo != g_PipelineRangeTo || previousReplayDir != g_PipelineReplayInputDir || previousIncludeMineReplay != g_PipelineIncludeMineReplay) {
        UpdatePipelineCommand();
        g_PipelineCopyStatus = "";
    }

    UI::Text("Mine replay: " + (g_MineReplayPath.Length > 0 ? g_MineReplayPath : BuildMineReplayStoragePath()));
    if (UI::Button(g_MineReplayDownloadRunning ? "Downloading mine replay" : "Download mine replay")) {
        StartMineReplayDownload();
    }
    if (g_MineReplayDownloadStatus.Length > 0) {
        UI::TextWrapped(g_MineReplayDownloadStatus);
    }

    if (UI::Button("Generate command")) {
        UpdatePipelineCommand();
        RefreshBundleFiles();
        g_PipelineCopyStatus = "";
    }

    if (UI::Button("Copy command")) {
        UpdatePipelineCommand();
        IO::SetClipboard(g_PipelineCommand);
        g_PipelineCopyStatus = "Copied.";
    }

    UI::TextWrapped(g_PipelineCommand);
    if (g_PipelineCopyStatus.Length > 0) {
        UI::Text(g_PipelineCopyStatus);
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
        UI::Text("Bundle range: " + GetSelectedBundleLabel());
        UI::Text("Bundle file: " + g_SelectedBundleFileName);
        UI::Text("Mine run: -");
        UI::Text("Runs: 0");
        UI::Text("Center points: 0");
        UI::Text("Mine points: 0");
        UI::Text("Problem zones: 0");
        return;
    }

    UI::Text("Map: " + (g_Bundle.mapName.Length > 0 ? g_Bundle.mapName : "-"));
    UI::Text("Current map: " + (g_CurrentMapName.Length > 0 ? g_CurrentMapName : "-"));
    UI::Text("Bundle range: " + GetSelectedBundleLabel());
    UI::Text("Bundle file: " + g_SelectedBundleFileName);
    UI::Text("Mine run: " + (g_Bundle.mineRunName.Length > 0 ? g_Bundle.mineRunName : "-"));
    UI::Text("Runs: " + g_Bundle.runs.Length);
    UI::Text("Center points: " + g_Bundle.centerLine.Length);
    UI::Text("Mine points: " + g_Bundle.mineLine.Length);
    UI::Text("Problem zones: " + g_Bundle.problemZones.Length);
    UI::Text("Projected center segments: " + g_LastProjectedCenterSegments);
    UI::Text("Skipped center segments: " + g_LastSkippedCenterSegments);
    UI::Text("Projected mine segments: " + g_LastProjectedMineSegments);
    UI::Text("Skipped mine segments: " + g_LastSkippedMineSegments);
    UI::Text("Projected other run segments: " + g_LastProjectedOtherRunSegments);
    UI::Text("Skipped other run segments: " + g_LastSkippedOtherRunSegments);
    UI::Text("Projected problem zones: " + g_LastProjectedProblemZones);
    UI::Text("Skipped problem zones: " + g_LastSkippedProblemZones);
    UI::Text("Viewport cameras: " + g_LastCameraCount);
}

void RenderToggleSection() {
    UI::Text("Toggles");
    g_ShowCenter = UI::Checkbox("Show Center", g_ShowCenter);
    g_ColorCenterBySpeedDelta = UI::Checkbox("Color Center By Speed Delta", g_ColorCenterBySpeedDelta);
    g_ShowMine = UI::Checkbox("Show Mine", g_ShowMine);
    g_ShowOtherRuns = UI::Checkbox("Show Other Runs", g_ShowOtherRuns);
    g_ShowProblemZones = UI::Checkbox("Show Problem Zones", g_ShowProblemZones);

    UI::Text("Render Settings");
    g_ShowFullTrajectory = UI::Checkbox("Show Full Trajectory", g_ShowFullTrajectory);
    if (!g_ShowFullTrajectory) {
        g_RenderDistance = UI::SliderFloat("Render Distance", g_RenderDistance, 50.0f, 2000.0f);
    }
    g_CenterLineWidth = UI::SliderFloat("Center width", g_CenterLineWidth, 1.0f, 10.0f);
    g_MineLineWidth = UI::SliderFloat("Mine width", g_MineLineWidth, 1.0f, 10.0f);
    g_OtherRunLineWidth = UI::SliderFloat("Other runs width", g_OtherRunLineWidth, 0.5f, 5.0f);
    g_ProblemZoneMarkerSize = UI::SliderFloat("Problem marker size", g_ProblemZoneMarkerSize, 2.0f, 32.0f);
    g_MaxVisibleProblemZones = UI::SliderInt("Problem zones", g_MaxVisibleProblemZones, 0, 20);
}
