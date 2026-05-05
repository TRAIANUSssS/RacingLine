void RenderWindow() {
    if (!g_ShowWindow) {
        return;
    }

    UI::SetNextWindowSize(420, 320, UI::Cond::FirstUseEver);
    if (UI::Begin("RacingLine", g_ShowWindow)) {
        if (g_DevMode) {
            RenderDevWindowContent();
        } else {
            RenderUserWindowContent();
        }
    }
    UI::End();
}

void RenderDevWindowContent() {
    RenderStatusSection();
    UI::Separator();
    RenderDataSection();
    UI::Separator();
    RenderPipelineSection();
    UI::Separator();
    RenderToggleSection();
    UI::Separator();
    RenderInfoSection();
    UI::Separator();
    g_DevMode = UI::Checkbox("Dev mode", g_DevMode);
}

void RenderUserWindowContent() {
    AutoRefreshBundleFiles();
    AutoRefreshHelperStatus();
    UpdatePipelineCommand();

    UI::Text("Current map: " + (g_CurrentMapName.Length > 0 ? g_CurrentMapName : "-"));

    if (g_AvailableBundleFiles.Length == 0) {
        UI::Text("Bundle: " + GetSelectedBundleLabel());
    } else {
        UI::SetNextItemWidth(220.0f);
        if (UI::BeginCombo("Bundle", GetSelectedBundleLabel())) {
            for (uint i = 0; i < g_AvailableBundleFiles.Length; i++) {
                bool isSelected = int(i) == g_SelectedBundleIndex;
                if (UI::Selectable(g_AvailableBundleLabels[i] + "##user-bundle-" + g_AvailableBundleFiles[i], isSelected)) {
                    g_SelectedBundleFileName = g_AvailableBundleFiles[i];
                    g_SelectedBundleFolderName = g_AvailableBundleFolders[i];
                    g_SelectedBundleIndex = int(i);
                    ReloadBundle();
                }
            }
            UI::EndCombo();
        }
    }

    if (UI::Button("Reload")) {
        ReloadBundle();
    }
    UI::SameLine();
    if (UI::Button("Refresh bundles")) {
        RefreshBundleFiles();
    }

    UI::Separator();
    UI::Text("Generate new bundle");
    RenderUserRankControls();
    RenderLeaderboardDownloadSection(false);
    RenderHelperStatusSection(false);

    g_PipelineAutoSamples = UI::Checkbox("Auto samples", g_PipelineAutoSamples);
    if (g_PipelineAutoSamples) {
        UI::Text("Sample density: 10 points/sec");
    } else {
        g_PipelineManualSamples = UI::SliderInt("Sample points", g_PipelineManualSamples, 50, 3000);
        NormalizePipelineRange();
    }

    UI::Separator();
    RenderUserToggleGrid();

    UI::TextWrapped("Showing other runs or the full trajectory can heavily affect performance.");

    g_ShowAdvancedOptions = UI::Checkbox("Extra options", g_ShowAdvancedOptions);
    if (g_ShowAdvancedOptions) {
        RenderRenderSettingsSliders();
    }

    g_DevMode = UI::Checkbox("Dev mode (You don't need to click here ;)", g_DevMode);
}

void RenderUserRankControls() {
    UI::AlignTextToFramePadding();
    UI::Text("Rank from");
    UI::SameLine();
    UI::SetNextItemWidth(110.0f);
    g_PipelineRangeFrom = UI::InputInt("##user-rank-from", g_PipelineRangeFrom);
    UI::SameLine();
    UI::AlignTextToFramePadding();
    UI::Text("to");
    UI::SameLine();
    UI::SetNextItemWidth(110.0f);
    g_PipelineRangeTo = UI::InputInt("##user-rank-to", g_PipelineRangeTo);
    UI::SameLine();
    UI::AlignTextToFramePadding();
    UI::Text("Max " + PipelineMaxRank);
    NormalizePipelineRange();
}

void RenderUserToggleGrid() {
    if (UI::BeginTable("toggle-grid", 2)) {
        UI::TableNextColumn();
        g_ShowCenter = UI::Checkbox("Show Center", g_ShowCenter);
        UI::TableNextColumn();
        g_ShowMine = UI::Checkbox("Show Mine", g_ShowMine);
        UI::TableNextColumn();
        g_ShowOtherRuns = UI::Checkbox("Show Other Runs", g_ShowOtherRuns);
        UI::TableNextColumn();
        g_ShowProblemZones = UI::Checkbox("Show Problem Zones", g_ShowProblemZones);
        UI::TableNextColumn();
        g_ColorCenterBySpeedDelta = UI::Checkbox("Color Center By Speed Delta", g_ColorCenterBySpeedDelta);
        UI::TableNextColumn();
        g_ShowFullTrajectory = UI::Checkbox("Show Full Trajectory", g_ShowFullTrajectory);
        UI::EndTable();
    }
}

void RenderDataSection() {
    AutoRefreshBundleFiles();

    UI::Text("Data");
    UI::Text("Current map: " + (g_CurrentMapName.Length > 0 ? g_CurrentMapName : "-"));
    UI::Text("Current map uid: " + (g_CurrentMapUid.Length > 0 ? g_CurrentMapUid : "-"));
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
                g_SelectedBundleFolderName = g_AvailableBundleFolders[i];
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
    AutoRefreshHelperStatus();
    UpdatePipelineCommand();

    string previousRoot = g_PipelineProjectRoot;
    int previousRangeFrom = g_PipelineRangeFrom;
    int previousRangeTo = g_PipelineRangeTo;
    string previousReplayDir = g_PipelineReplayInputDir;
    bool previousReplayDirAuto = g_PipelineReplayInputDirAuto;
    bool previousIncludeMineReplay = g_PipelineIncludeMineReplay;
    bool previousAutoSamples = g_PipelineAutoSamples;
    int previousManualSamples = g_PipelineManualSamples;
    bool previousWritePlots = g_PipelineWritePlots;

    g_PipelineProjectRoot = UI::InputText("Project root", g_PipelineProjectRoot);
    g_PipelineRangeFrom = UI::InputInt("Rank from", g_PipelineRangeFrom);
    g_PipelineRangeTo = UI::InputInt("Rank to", g_PipelineRangeTo);
    g_PipelineAutoSamples = UI::Checkbox("Auto samples", g_PipelineAutoSamples);
    if (g_PipelineAutoSamples) {
        UI::Text("Sample density: 10 points/sec");
    } else {
        g_PipelineManualSamples = UI::SliderInt("Sample points", g_PipelineManualSamples, 50, 3000);
    }
    g_PipelineWritePlots = UI::Checkbox("Write debug plots", g_PipelineWritePlots);
    g_PipelineReplayInputDirAuto = UI::Checkbox("Auto replay dir", g_PipelineReplayInputDirAuto);
    string autoReplayInputDir = BuildDefaultReplayInputDir(g_CurrentMapName, g_CurrentMapUid);
    if (g_PipelineReplayInputDirAuto) {
        g_PipelineReplayInputDir = autoReplayInputDir;
    }
    g_PipelineReplayInputDir = UI::InputText("Replay dir", g_PipelineReplayInputDir);
    if (g_PipelineReplayInputDirAuto && g_PipelineReplayInputDir != autoReplayInputDir) {
        g_PipelineReplayInputDirAuto = false;
    }
    g_PipelineIncludeMineReplay = UI::Checkbox("Use mine replay", g_PipelineIncludeMineReplay);
    NormalizePipelineRange();

    if (previousRoot != g_PipelineProjectRoot || previousRangeFrom != g_PipelineRangeFrom || previousRangeTo != g_PipelineRangeTo || previousReplayDir != g_PipelineReplayInputDir || previousReplayDirAuto != g_PipelineReplayInputDirAuto || previousIncludeMineReplay != g_PipelineIncludeMineReplay || previousAutoSamples != g_PipelineAutoSamples || previousManualSamples != g_PipelineManualSamples || previousWritePlots != g_PipelineWritePlots) {
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

    UI::Separator();
    RenderLeaderboardDownloadSection(true);
    UI::Separator();
    RenderHelperStatusSection(true);

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

void RenderLeaderboardDownloadSection(bool devMode) {
    NormalizePipelineRange();

    UI::Text("Leaderboard records + mine replay");
    string destination = g_LeaderboardDownloadFolder.Length > 0
        ? g_LeaderboardDownloadFolder
        : BuildCurrentLeaderboardDownloadStoragePath();
    UI::TextWrapped("Destination: " + destination);

    if (UI::Button(g_LeaderboardDownloadRunning ? "Downloading records" : "Download records")) {
        StartLeaderboardDownload(false);
    }
    UI::SameLine();
    if (UI::Button("Force download")) {
        StartLeaderboardDownload(true);
    }

    if (g_LeaderboardDownloadStatus.Length > 0) {
        UI::TextWrapped(g_LeaderboardDownloadStatus);
    }
    UI::Text("Downloaded: " + g_LeaderboardDownloadedCount + "  Skipped: " + g_LeaderboardSkippedCount + "  Failed: " + g_LeaderboardFailedCount);

    if (devMode) {
        UI::Text("Total entries: " + g_LeaderboardTotalCount);
    }
}

void RenderHelperStatusSection(bool devMode) {
    UI::Text("Local helper");
    UI::TextWrapped("Status: " + g_HelperStatus + (g_HelperProgress.Length > 0 ? " / " + g_HelperProgress : ""));
    if (g_HelperError.Length > 0) {
        UI::TextWrapped("Error: " + g_HelperError);
    }
    if (devMode && g_HelperLogPath.Length > 0) {
        UI::TextWrapped("Log: " + g_HelperLogPath);
    }
    if (UI::Button("Refresh helper status")) {
        RefreshHelperStatus();
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
    UI::Text("Map uid: " + (g_Bundle.mapUid.Length > 0 ? g_Bundle.mapUid : "-"));
    UI::Text("Current map: " + (g_CurrentMapName.Length > 0 ? g_CurrentMapName : "-"));
    UI::Text("Bundle range: " + (g_Bundle.rankRange.Length > 0 ? g_Bundle.rankRange : GetSelectedBundleLabel()));
    UI::Text("Bundle file: " + g_SelectedBundleFileName);
    UI::Text("Sample mode: " + (g_Bundle.sampleMode.Length > 0 ? g_Bundle.sampleMode : "-"));
    UI::Text("Sample count: " + g_Bundle.sampleCount);
    UI::Text("Generator: " + (g_Bundle.generator.Length > 0 ? g_Bundle.generator : "-"));
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
    UI::Text("Route window: " + (g_RouteWindowAvailable ? "on" : "off"));
    UI::Text("Route anchor: " + g_RenderAnchorIndex + "  window: " + g_VisibleIndexStart + "-" + g_VisibleIndexEnd);
    UI::Text("Route anchor distance: " + g_LastRouteAnchorDistance);
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
    RenderRenderSettingsSliders();
}

void RenderRenderSettingsSliders() {
    g_UseRouteWindow = UI::Checkbox("Use Route Window", g_UseRouteWindow);
    if (g_UseRouteWindow) {
        g_RouteLookbehindDistance = UI::SliderFloat("Route lookbehind", g_RouteLookbehindDistance, 0.0f, 300.0f);
        g_RouteLookaheadDistance = UI::SliderFloat("Route lookahead", g_RouteLookaheadDistance, 50.0f, 1000.0f);
        g_RouteReacquireDistance = UI::SliderFloat("Route reacquire distance", g_RouteReacquireDistance, 20.0f, 500.0f);
        g_RouteAnchorBackSearchPoints = UI::SliderInt("Anchor back search", g_RouteAnchorBackSearchPoints, 0, 500);
        g_RouteAnchorForwardSearchPoints = UI::SliderInt("Anchor forward search", g_RouteAnchorForwardSearchPoints, 1, 1000);
    }
    if (!g_ShowFullTrajectory) {
        g_RenderDistance = UI::SliderFloat("Render Distance", g_RenderDistance, 50.0f, 2000.0f);
    }
    g_CenterLineWidth = UI::SliderFloat("Center width", g_CenterLineWidth, 1.0f, 10.0f);
    g_MineLineWidth = UI::SliderFloat("Mine width", g_MineLineWidth, 1.0f, 10.0f);
    g_OtherRunLineWidth = UI::SliderFloat("Other runs width", g_OtherRunLineWidth, 0.5f, 5.0f);
    g_ProblemZoneMarkerSize = UI::SliderFloat("Problem marker size", g_ProblemZoneMarkerSize, 2.0f, 32.0f);
    g_MaxVisibleProblemZones = UI::SliderInt("Problem zones", g_MaxVisibleProblemZones, 0, 20);
}
