AnalysisBundle@ g_Bundle = null;
bool g_BundleLoaded = false;
string g_LastError = "";

bool g_ShowWindow = true;
bool g_ShowCenter = true;
bool g_ShowMine = true;
bool g_ShowProblemZones = true;

string g_BundlePath = BundlePath;

void Main() {
    ReloadBundle();
}

void RenderMenu() {
    if (UI::MenuItem("RacingLine", "", g_ShowWindow)) {
        g_ShowWindow = !g_ShowWindow;
    }
}

void Render() {
    RenderWindow();
}

void ReloadBundle() {
    bool loaded = LoadBundle(g_BundlePath);
    if (!loaded && g_LastError.Length == 0) {
        g_LastError = "Unknown bundle loading error.";
    }
}
RacingLine