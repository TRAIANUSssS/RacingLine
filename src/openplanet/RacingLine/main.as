AnalysisBundle@ g_Bundle = null;
bool g_BundleLoaded = false;
string g_LastError = "";

bool g_ShowWindow = true;
bool g_ShowCenter = true;
bool g_ShowMine = true;
bool g_ShowProblemZones = true;
bool g_ColorCenterBySpeedDelta = false;

string g_CurrentMapName = "";
string g_CurrentMapFolderName = "";
string g_CurrentUserName = "";
string g_CurrentUserLogin = "";
string g_SelectedBundleFileName = DefaultBundleFileName;
string g_BundlePath = "";
array<string> g_AvailableBundleFiles;
int g_SelectedBundleIndex = -1;

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
