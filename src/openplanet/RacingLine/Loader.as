bool LoadBundle(const string &in path) {
    g_LastError = "";
    @g_Bundle = null;
    g_BundleLoaded = false;

    string trimmedPath = path.Trim();
    if (trimmedPath.Length == 0) {
        g_LastError = "Bundle path is empty.";
        return false;
    }

    string resolvedPath = ResolveBundlePath(trimmedPath);
    if (!IO::FileExists(resolvedPath)) {
        g_LastError = "Bundle file not found: " + resolvedPath;
        return false;
    }

    string content;
    try {
        IO::File file(resolvedPath, IO::FileMode::Read);
        content = file.ReadToEnd();
        file.Close();
    } catch {
        g_LastError = "Failed to read bundle file: " + resolvedPath;
        return false;
    }

    Json::Value@ root;
    try {
        @root = Json::Parse(content);
    } catch {
        g_LastError = "Invalid JSON in bundle file.";
        return false;
    }

    if (root is null || root.GetType() != Json::Type::Object) {
        g_LastError = "Bundle root must be a JSON object.";
        return false;
    }

    AnalysisBundle@ bundle = AnalysisBundle();
    Json::Value@ mapObj = root.Get("map");
    if (mapObj !is null && mapObj.GetType() == Json::Type::Object) {
        bundle.mapName = JsonGetString(mapObj, "name");
    }
    bundle.mineRunName = JsonGetString(root, "mine_run_name");

    Json::Value@ centerArray = root.Get("center_line");
    if (centerArray !is null && centerArray.GetType() == Json::Type::Array) {
        for (uint i = 0; i < centerArray.Length; i++) {
            Json::Value@ item = centerArray[i];
            if (item is null || item.GetType() != Json::Type::Object) {
                continue;
            }

            CenterPoint@ point = ParseCenterPoint(item);
            if (point !is null) {
                bundle.centerLine.InsertLast(point);
            }
        }
    }

    Json::Value@ mineArray = root.Get("mine_line");
    if (mineArray !is null && mineArray.GetType() == Json::Type::Array) {
        for (uint i = 0; i < mineArray.Length; i++) {
            Json::Value@ item = mineArray[i];
            if (item is null || item.GetType() != Json::Type::Object) {
                continue;
            }

            MinePoint@ point = ParseMinePoint(item);
            if (point !is null) {
                bundle.mineLine.InsertLast(point);
            }
        }
    }

    Json::Value@ analysisArray = root.Get("analysis_points");
    if (analysisArray !is null && analysisArray.GetType() == Json::Type::Array) {
        for (uint i = 0; i < analysisArray.Length; i++) {
            Json::Value@ item = analysisArray[i];
            if (item is null || item.GetType() != Json::Type::Object) {
                continue;
            }

            AnalysisPoint@ point = ParseAnalysisPoint(item);
            if (point !is null) {
                bundle.analysisPoints.InsertLast(point);
            }
        }
    }

    Json::Value@ zonesArray = root.Get("problem_zones");
    if (zonesArray !is null && zonesArray.GetType() == Json::Type::Array) {
        for (uint i = 0; i < zonesArray.Length; i++) {
            Json::Value@ item = zonesArray[i];
            if (item is null || item.GetType() != Json::Type::Object) {
                continue;
            }

            ProblemZone@ zone = ParseProblemZone(item);
            if (zone !is null) {
                bundle.problemZones.InsertLast(zone);
            }
        }
    }

    @g_Bundle = bundle;
    g_BundleLoaded = true;
    return true;
}

string ResolveBundlePath(const string &in path) {
    if (path.Length == 0) {
        return path;
    }

    if (path.StartsWith("/") || path.StartsWith("\\") || path.StartsWith(".") || path.StartsWith("C:") || path.StartsWith("D:")) {
        return path;
    }

    return IO::FromStorageFolder("") + path;
}

CenterPoint@ ParseCenterPoint(Json::Value@ json) {
    if (json is null || json.GetType() != Json::Type::Object) {
        return null;
    }

    CenterPoint@ point = CenterPoint();
    point.progress = JsonGetFloat(json, "progress");
    point.pos = vec3(
        JsonGetFloat(json, "x"),
        JsonGetFloat(json, "y"),
        JsonGetFloat(json, "z")
    );
    point.speed = JsonGetFloat(json, "speed");
    point.spread = JsonGetFloat(json, "spread");
    return point;
}

MinePoint@ ParseMinePoint(Json::Value@ json) {
    if (json is null || json.GetType() != Json::Type::Object) {
        return null;
    }

    MinePoint@ point = MinePoint();
    point.progress = JsonGetFloat(json, "progress");
    point.pos = vec3(
        JsonGetFloat(json, "x"),
        JsonGetFloat(json, "y"),
        JsonGetFloat(json, "z")
    );
    point.speed = JsonGetFloat(json, "speed");
    return point;
}

AnalysisPoint@ ParseAnalysisPoint(Json::Value@ json) {
    if (json is null || json.GetType() != Json::Type::Object) {
        return null;
    }

    AnalysisPoint@ point = AnalysisPoint();
    point.progress = JsonGetFloat(json, "progress");
    point.deviation = JsonGetFloat(json, "deviation");
    point.importance = JsonGetFloat(json, "importance");
    point.speedDelta = JsonGetFloat(json, "speed_delta");
    return point;
}

ProblemZone@ ParseProblemZone(Json::Value@ json) {
    if (json is null || json.GetType() != Json::Type::Object) {
        return null;
    }

    ProblemZone@ zone = ProblemZone();
    zone.rank = JsonGetInt(json, "rank");
    zone.index = JsonGetInt(json, "index");
    zone.progress = JsonGetFloat(json, "progress");
    zone.importance = JsonGetFloat(json, "importance");
    zone.deviation = JsonGetFloat(json, "deviation");
    zone.spread = JsonGetFloat(json, "spread");
    zone.centerSpeed = JsonGetFloat(json, "center_speed");
    zone.mineSpeed = JsonGetFloat(json, "mine_speed");
    zone.pos = vec3(
        JsonGetFloat(json, "x"),
        JsonGetFloat(json, "y"),
        JsonGetFloat(json, "z")
    );
    return zone;
}

string JsonGetString(Json::Value@ obj, const string &in key) {
    if (obj is null || obj.GetType() != Json::Type::Object) {
        return "";
    }

    Json::Value@ value = obj.Get(key);
    if (value is null || value.GetType() == Json::Type::Null) {
        return "";
    }

    try {
        return string(value);
    } catch {
        return "";
    }
}

float JsonGetFloat(Json::Value@ obj, const string &in key) {
    if (obj is null || obj.GetType() != Json::Type::Object) {
        return 0.0f;
    }

    Json::Value@ value = obj.Get(key);
    if (value is null || value.GetType() == Json::Type::Null) {
        return 0.0f;
    }

    try {
        return float(value);
    } catch {
        return 0.0f;
    }
}

int JsonGetInt(Json::Value@ obj, const string &in key) {
    if (obj is null || obj.GetType() != Json::Type::Object) {
        return 0;
    }

    Json::Value@ value = obj.Get(key);
    if (value is null || value.GetType() == Json::Type::Null) {
        return 0;
    }

    try {
        return int(value);
    } catch {
        return 0;
    }
}
