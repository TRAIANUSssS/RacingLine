bool g_WindowOpen = true;
bool g_ShowCenterLine = true;
bool g_ShowMineLine = true;
bool g_ShowProblemZones = true;

string g_BundlePath = "analysis_bundle.json";
string g_Status = "Bundle loading is not implemented yet.";

void Main()
{
    // MVP viewer shell. Bundle parsing/rendering should stay lightweight here;
    // offline Python tooling owns analysis and writes analysis_bundle.json.
}

void RenderMenu()
{
    if (UI::MenuItem("RacingLine", "", g_WindowOpen)) {
        g_WindowOpen = !g_WindowOpen;
    }
}

void RenderInterface()
{
    if (!g_WindowOpen) {
        return;
    }

    UI::SetNextWindowSize(420, 250, UI::Cond::FirstUseEver);
    if (UI::Begin("RacingLine", g_WindowOpen)) {
        UI::Text("Viewer-first Trackmania trajectory overlay");
        UI::Separator();

        UI::InputText("Bundle path", g_BundlePath);
        if (UI::Button("Load bundle")) {
            LoadBundle();
        }

        UI::Separator();
        UI::Checkbox("Center line", g_ShowCenterLine);
        UI::Checkbox("Mine line", g_ShowMineLine);
        UI::Checkbox("Problem zones", g_ShowProblemZones);

        UI::Separator();
        UI::TextWrapped(g_Status);
    }
    UI::End();
}

void Render()
{
    // TODO: Project bundle world points to screen space and draw enabled overlays.
}

void LoadBundle()
{
    g_Status = "TODO: parse " + g_BundlePath + " and cache center/mine/problem zone geometry.";
}

