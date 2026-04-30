const string NadeoCoreAudience = "NadeoServices";

void StartMineReplayDownload() {
    if (g_MineReplayDownloadRunning) {
        return;
    }

    startnew(DownloadMineReplayCoroutine);
}

void DownloadMineReplayCoroutine() {
    g_MineReplayDownloadRunning = true;
    g_MineReplayDownloadStatus = "Starting.";
    g_MineReplayPath = BuildMineReplayStoragePath();

    try {
        DownloadMineReplayNow(true, false);
    } catch {
        g_MineReplayDownloadStatus = "Mine replay download failed.";
    }

    g_MineReplayDownloadRunning = false;
}

bool DownloadMineReplayNow(bool force, bool reuseExisting) {
    g_MineReplayPath = BuildMineReplayStoragePath();

    if (reuseExisting && !force && IO::FileExists(g_MineReplayPath)) {
        g_MineReplayDownloadStatus = "Mine replay already exists: " + g_MineReplayPath;
        return true;
    }

    if (!WaitForNadeoCoreAuth()) {
        g_MineReplayDownloadStatus = "NadeoServices authentication timed out.";
        return false;
    }

    string accountId = NadeoServices::GetAccountID();
    string mapUid = GetCurrentMapUid();
    if (accountId.Length == 0) {
        g_MineReplayDownloadStatus = "Current account id is not available.";
        return false;
    }
    if (mapUid.Length == 0) {
        g_MineReplayDownloadStatus = "Current map uid is not available.";
        return false;
    }

    g_MineReplayDownloadStatus = "Resolving map id.";
    string mapId = ResolveCachedMapId(mapUid);
    if (mapId.Length == 0) {
        g_MineReplayDownloadStatus = "Map id was not found for current map uid.";
        return false;
    }

    g_MineReplayDownloadStatus = "Resolving mine replay URL.";
    string replayUrl = FetchMineReplayUrl(accountId, mapId);
    if (replayUrl.Length == 0) {
        g_MineReplayDownloadStatus = "Mine personal best record was not found for this map.";
        return false;
    }

    string replayPath = BuildMineReplayStoragePath();
    IO::CreateFolder(BuildMineReplayStorageFolderPath(), true);

    g_MineReplayDownloadStatus = "Downloading mine replay.";
    Net::HttpRequest@ replayRequest = NadeoServices::Get(NadeoCoreAudience, replayUrl);
    await(replayRequest.StartToFile(replayPath));
    if (!RequestSucceeded(replayRequest)) {
        g_MineReplayDownloadStatus = "Mine replay download failed: HTTP " + replayRequest.ResponseCode() + " " + replayRequest.Error();
        return false;
    }

    g_MineReplayPath = replayPath;
    WriteMineReplayManifest(accountId, mapUid, mapId, replayUrl, replayPath);
    g_MineReplayDownloadStatus = "Saved: " + replayPath;
    return true;
}

bool WaitForNadeoCoreAuth() {
    for (uint i = 0; i < 100; i++) {
        if (NadeoServices::IsAuthenticated(NadeoCoreAudience)) {
            return true;
        }
        sleep(100);
    }
    return false;
}

string FetchMapId(const string &in mapUid) {
    string url = NadeoServices::BaseURLCore() + "/maps/by-uid/?mapUidList=" + Net::UrlEncode(mapUid);
    Net::HttpRequest@ request = NadeoServices::Get(NadeoCoreAudience, url);
    await(request.Start());
    if (!RequestSucceeded(request)) {
        return "";
    }

    Json::Value@ root = request.Json();
    if (root is null || root.GetType() != Json::Type::Array || root.Length == 0) {
        return "";
    }

    Json::Value@ mapInfo = root[0];
    if (mapInfo is null || mapInfo.GetType() != Json::Type::Object) {
        return "";
    }

    return JsonGetString(mapInfo, "mapId");
}

string FetchMineReplayUrl(const string &in accountId, const string &in mapId) {
    string url = NadeoServices::BaseURLCore()
        + "/v2/mapRecords/by-account/?accountIdList=" + Net::UrlEncode(accountId)
        + "&mapId=" + Net::UrlEncode(mapId);

    Net::HttpRequest@ request = NadeoServices::Get(NadeoCoreAudience, url);
    await(request.Start());
    if (!RequestSucceeded(request)) {
        return "";
    }

    Json::Value@ root = request.Json();
    if (root is null || root.GetType() != Json::Type::Array || root.Length == 0) {
        return "";
    }

    Json::Value@ record = root[0];
    if (record is null || record.GetType() != Json::Type::Object) {
        return "";
    }

    return JsonGetString(record, "url");
}

bool RequestSucceeded(Net::HttpRequest@ request) {
    if (request is null) {
        return false;
    }

    int code = request.ResponseCode();
    return code >= 200 && code < 300 && request.Error().Length == 0;
}

string GetCurrentMapUid() {
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) {
        return "";
    }

    return string(app.RootMap.MapInfo.MapUid).Trim();
}

string BuildMineReplayStorageRelativePath() {
    string folder = g_CurrentMapFolderName.Length > 0 ? g_CurrentMapFolderName : SanitizePathSegment(g_CurrentMapName);
    if (folder.Length == 0) {
        folder = "unknown_map";
    }
    return MineReplayTmpDirectory + "/" + folder + "/mine.Replay.Gbx";
}

string BuildMineReplayStorageRelativeFolderPath() {
    string folder = g_CurrentMapFolderName.Length > 0 ? g_CurrentMapFolderName : SanitizePathSegment(g_CurrentMapName);
    if (folder.Length == 0) {
        folder = "unknown_map";
    }
    return MineReplayTmpDirectory + "/" + folder;
}

string BuildMineReplayStoragePath() {
    return IO::FromStorageFolder(BuildMineReplayStorageRelativePath());
}

string BuildMineReplayStorageFolderPath() {
    return IO::FromStorageFolder(BuildMineReplayStorageRelativeFolderPath());
}

void WriteMineReplayManifest(
    const string &in accountId,
    const string &in mapUid,
    const string &in mapId,
    const string &in replayUrl,
    const string &in replayPath
) {
    string path = IO::FromStorageFolder(BuildMineReplayStorageRelativeFolderPath() + "/mine_replay_manifest.json");
    IO::File file(path, IO::FileMode::Write);
    file.Write("{\n");
    file.Write("  \"schema\": \"racingline.mine_replay_manifest.v1\",\n");
    file.Write("  \"account_id\": \"" + JsonEscape(accountId) + "\",\n");
    file.Write("  \"map_uid\": \"" + JsonEscape(mapUid) + "\",\n");
    file.Write("  \"map_id\": \"" + JsonEscape(mapId) + "\",\n");
    file.Write("  \"replay_url\": \"" + JsonEscape(replayUrl) + "\",\n");
    file.Write("  \"replay_path\": \"" + JsonEscape(replayPath) + "\"\n");
    file.Write("}\n");
    file.Close();
}

string JsonEscape(const string &in value) {
    string result = "";
    for (uint i = 0; i < value.Length; i++) {
        string ch = value.SubStr(i, 1);
        if (ch == "\\") {
            result += "\\\\";
        } else if (ch == "\"") {
            result += "\\\"";
        } else if (ch == "\n") {
            result += "\\n";
        } else if (ch == "\r") {
            result += "\\r";
        } else if (ch == "\t") {
            result += "\\t";
        } else {
            result += ch;
        }
    }
    return result;
}
