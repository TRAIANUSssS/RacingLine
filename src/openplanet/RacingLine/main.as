AnalysisBundle@ g_Bundle = null;
bool g_BundleLoaded = false;
string g_LastError = "";

bool g_ShowWindow = true;
bool g_ShowCenter = true;
bool g_ShowMine = true;
bool g_ShowProblemZones = true;
bool g_ColorCenterBySpeedDelta = false;
float g_CenterLineWidth = CenterLineWidth;
float g_MineLineWidth = MineLineWidth;
float g_ProblemZoneMarkerSize = ProblemZoneMarkerSize;
int g_MaxVisibleProblemZones = MaxVisibleProblemZones;

string g_CurrentMapName = "";
string g_CurrentMapFolderName = "";
string g_CurrentUserName = "";
string g_CurrentUserLogin = "";
string g_SelectedBundleFileName = DefaultBundleFileName;
string g_BundlePath = "";
array<string> g_AvailableBundleFiles;
int g_SelectedBundleIndex = -1;
string g_PipelineProjectRoot = PipelineProjectRoot;
int g_PipelineRangeFrom = PipelineDefaultRangeFrom;
int g_PipelineRangeTo = PipelineDefaultRangeTo;
string g_PipelineReplayInputDir = "";
string g_PipelineCommand = "";
string g_PipelineCopyStatus = "";

void Main() {
    UpdateCurrentMap(true);
}

void RenderMenu() {
    if (UI::MenuItem("RacingLine", "", g_ShowWindow)) {
        g_ShowWindow = !g_ShowWindow;
    }
}

void Render() {
    UpdateCurrentUser();
    UpdateCurrentMap(false);
    RenderWindow();
    RenderWorldOverlay();
}

void ReloadBundle() {
    if (g_CurrentMapFolderName.Length == 0) {
        @g_Bundle = null;
        g_BundleLoaded = false;
        g_LastError = "Current map is not detected.";
        return;
    }

    if (g_SelectedBundleFileName.Length == 0) {
        g_SelectedBundleFileName = DefaultBundleFileName;
    }

    g_BundlePath = BuildCurrentMapBundlePath(g_SelectedBundleFileName);
    bool loaded = LoadBundle(g_BundlePath);
    if (!loaded && g_LastError.Length == 0) {
        g_LastError = "Unknown bundle loading error.";
    }
}

void UpdateCurrentMap(bool force) {
    string mapName = GetCurrentMapName();
    if (!force && mapName == g_CurrentMapName) {
        return;
    }

    g_CurrentMapName = mapName;
    g_CurrentMapFolderName = SanitizePathSegment(mapName);
    g_SelectedBundleFileName = DefaultBundleFileName;
    g_PipelineReplayInputDir = BuildDefaultReplayInputDir(mapName);
    UpdatePipelineCommand();
    RefreshBundleFiles();
    ReloadBundle();
}

string GetCurrentMapName() {
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null || app.RootMap is null) {
        return "";
    }

    return string(app.RootMap.MapName).Trim();
}

void UpdateCurrentUser() {
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null || app.LocalPlayerInfo is null) {
        g_CurrentUserName = "";
        g_CurrentUserLogin = "";
        return;
    }

    g_CurrentUserName = string(app.LocalPlayerInfo.Name).Trim();
    g_CurrentUserLogin = string(app.LocalPlayerInfo.Login).Trim();
}

void RefreshBundleFiles() {
    g_AvailableBundleFiles.Resize(0);
    g_SelectedBundleIndex = -1;

    if (g_CurrentMapFolderName.Length == 0) {
        return;
    }

    string bundleFolderPath = GetCurrentMapBundleFolderPath();
    try {
        auto files = IO::IndexFolder(bundleFolderPath, false);
        for (uint i = 0; i < files.Length; i++) {
            string fileName = FileNameFromPath(files[i]);
            if (!fileName.EndsWith(".analysis_bundle.json")) {
                continue;
            }

            g_AvailableBundleFiles.InsertLast(fileName);
            if (fileName == g_SelectedBundleFileName) {
                g_SelectedBundleIndex = int(g_AvailableBundleFiles.Length) - 1;
            }
        }
    } catch {
        return;
    }

    if (g_SelectedBundleIndex >= 0) {
        return;
    }

    for (uint i = 0; i < g_AvailableBundleFiles.Length; i++) {
        if (g_AvailableBundleFiles[i] == DefaultBundleFileName) {
            g_SelectedBundleFileName = DefaultBundleFileName;
            g_SelectedBundleIndex = int(i);
            return;
        }
    }

    if (g_AvailableBundleFiles.Length > 0) {
        g_SelectedBundleFileName = g_AvailableBundleFiles[0];
        g_SelectedBundleIndex = 0;
    } else {
        g_SelectedBundleFileName = DefaultBundleFileName;
    }
}

string BuildCurrentMapBundlePath(const string &in fileName) {
    return BundleRootDirectory + "/" + g_CurrentMapFolderName + "/" + fileName;
}

string GetCurrentMapBundleFolderPath() {
    return IO::FromStorageFolder(BundleRootDirectory + "/" + g_CurrentMapFolderName);
}

string FileNameFromPath(const string &in path) {
    int lastSeparator = -1;
    for (uint i = 0; i < path.Length; i++) {
        string ch = path.SubStr(i, 1);
        if (ch == "/" || ch == "\\") {
            lastSeparator = int(i);
        }
    }

    if (lastSeparator < 0) {
        return path;
    }

    return path.SubStr(uint(lastSeparator + 1));
}

string SanitizePathSegment(const string &in value) {
    string result = "";
    string trimmed = value.Trim();
    for (uint i = 0; i < trimmed.Length; i++) {
        string ch = trimmed.SubStr(i, 1);
        if (ch == "<" || ch == ">" || ch == ":" || ch == "\"" || ch == "/" || ch == "\\" || ch == "|" || ch == "?" || ch == "*") {
            result += "_";
        } else {
            result += ch;
        }
    }

    result = result.Trim();
    if (result.Length == 0) {
        return "";
    }
    return result;
}

void UpdatePipelineCommand() {
    string mapName = g_CurrentMapName.Length > 0 ? g_CurrentMapName : "<current_map>";
    string mineNickname = StripTrackmaniaFormatCodes(g_CurrentUserName).Trim();
    if (mineNickname.Length == 0) {
        mineNickname = g_CurrentUserLogin;
    }
    if (mineNickname.Length == 0) {
        mineNickname = "<current_nickname>";
    }

    NormalizePipelineRange();

    string command = "python .\\pipeline.py";
    command += " --map " + QuotePowerShell(mapName);
    command += " --mine " + QuotePowerShell(mineNickname);
    command += " --range " + QuotePowerShell(BuildPipelineRange());
    if (g_PipelineReplayInputDir.Trim().Length > 0) {
        command += " --replay-input-dir " + QuotePowerShell(g_PipelineReplayInputDir.Trim());
    }

    if (g_PipelineProjectRoot.Trim().Length > 0) {
        g_PipelineCommand = "Set-Location " + QuotePowerShell(g_PipelineProjectRoot.Trim()) + "; " + command;
    } else {
        g_PipelineCommand = command;
    }
}

void NormalizePipelineRange() {
    if (g_PipelineRangeFrom < 1) {
        g_PipelineRangeFrom = 1;
    }
    if (g_PipelineRangeTo < 1) {
        g_PipelineRangeTo = 1;
    }
    if (g_PipelineRangeTo < g_PipelineRangeFrom) {
        g_PipelineRangeTo = g_PipelineRangeFrom;
    }
    if (g_PipelineRangeTo - g_PipelineRangeFrom > 20) {
        g_PipelineRangeTo = g_PipelineRangeFrom + 20;
    }
}

string BuildPipelineRange() {
    return "" + g_PipelineRangeFrom + "-" + g_PipelineRangeTo;
}

string BuildDefaultReplayInputDir(const string &in mapName) {
    string number = ExtractTrailingMapNumber(mapName);
    if (number.Length == 0) {
        return ".\\data\\raw\\replays";
    }

    return ".\\data\\raw\\replays\\" + number;
}

string ExtractTrailingMapNumber(const string &in mapName) {
    string trimmed = mapName.Trim();
    string digits = "";
    for (int i = int(trimmed.Length) - 1; i >= 0; i--) {
        string ch = trimmed.SubStr(uint(i), 1);
        if (IsDigit(ch)) {
            digits = ch + digits;
            continue;
        }

        if (digits.Length > 0) {
            break;
        }
    }

    while (digits.Length > 1 && digits.SubStr(0, 1) == "0") {
        digits = digits.SubStr(1);
    }
    return digits;
}

bool IsDigit(const string &in value) {
    return value == "0" || value == "1" || value == "2" || value == "3" || value == "4"
        || value == "5" || value == "6" || value == "7" || value == "8" || value == "9";
}

string StripTrackmaniaFormatCodes(const string &in value) {
    string result = "";
    for (uint i = 0; i < value.Length; i++) {
        string ch = value.SubStr(i, 1);
        if (ch != "$") {
            result += ch;
            continue;
        }

        if (i + 3 < value.Length && IsHexDigit(value.SubStr(i + 1, 1)) && IsHexDigit(value.SubStr(i + 2, 1)) && IsHexDigit(value.SubStr(i + 3, 1))) {
            i += 3;
        } else if (i + 1 < value.Length) {
            i += 1;
        }
    }

    return result;
}

bool IsHexDigit(const string &in value) {
    return IsDigit(value)
        || value == "a" || value == "b" || value == "c" || value == "d" || value == "e" || value == "f"
        || value == "A" || value == "B" || value == "C" || value == "D" || value == "E" || value == "F";
}

string QuotePowerShell(const string &in value) {
    string escaped = "";
    for (uint i = 0; i < value.Length; i++) {
        string ch = value.SubStr(i, 1);
        if (ch == "\"") {
            escaped += "`\"";
        } else {
            escaped += ch;
        }
    }

    return "\"" + escaped + "\"";
}
