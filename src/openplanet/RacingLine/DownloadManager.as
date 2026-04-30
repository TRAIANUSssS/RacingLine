const string NadeoLiveAudience = "NadeoLiveServices";
const int LeaderboardDownloadMaxRankDelta = 20;

bool g_LeaderboardDownloadRunning = false;
bool g_LeaderboardDownloadForce = false;
string g_LeaderboardDownloadStatus = "Idle.";
string g_LeaderboardDownloadFolder = "";
int g_LeaderboardDownloadedCount = 0;
int g_LeaderboardSkippedCount = 0;
int g_LeaderboardFailedCount = 0;
int g_LeaderboardTotalCount = 0;
string g_MapIdCacheUid = "";
string g_MapIdCacheId = "";

class LeaderboardRecordDownload {
    int rank = 0;
    string accountId = "";
    int score = 0;
    int timestamp = 0;
    string mapRecordId = "";
    string recordUrl = "";
    string filename = "";
    string localPath = "";
    bool downloaded = false;
    bool skippedExisting = false;
    string error = "";
}

void StartLeaderboardDownload(bool force) {
    if (g_LeaderboardDownloadRunning) {
        return;
    }

    g_LeaderboardDownloadForce = force;
    startnew(DownloadLeaderboardCoroutine);
}

void DownloadLeaderboardCoroutine() {
    g_LeaderboardDownloadRunning = true;
    g_LeaderboardDownloadedCount = 0;
    g_LeaderboardSkippedCount = 0;
    g_LeaderboardFailedCount = 0;
    g_LeaderboardTotalCount = 0;
    g_LeaderboardDownloadStatus = "Starting.";

    array<LeaderboardRecordDownload@> entries;
    string mapUid = g_CurrentMapUid;
    string mapName = g_CurrentMapName;
    int rankFrom = g_PipelineRangeFrom;
    int rankTo = g_PipelineRangeTo;
    string mapId = "";

    try {
        NormalizePipelineRange();
        rankFrom = g_PipelineRangeFrom;
        rankTo = g_PipelineRangeTo;

        string validationError = ValidateLeaderboardDownloadInput(mapUid, rankFrom, rankTo);
        if (validationError.Length > 0) {
            g_LeaderboardDownloadStatus = "Failed: " + validationError;
            g_LeaderboardDownloadRunning = false;
            return;
        }

        g_LeaderboardDownloadFolder = BuildLeaderboardDownloadStoragePath(mapUid, rankFrom, rankTo);
        IO::CreateFolder(g_LeaderboardDownloadFolder, true);

        if (!WaitForNadeoCoreAuth()) {
            g_LeaderboardDownloadStatus = "Failed: NadeoServices authentication timed out.";
            g_LeaderboardDownloadRunning = false;
            return;
        }
        if (!WaitForNadeoLiveAuth()) {
            g_LeaderboardDownloadStatus = "Failed: NadeoLiveServices authentication timed out.";
            g_LeaderboardDownloadRunning = false;
            return;
        }

        g_LeaderboardDownloadStatus = "Preparing mine replay.";
        g_MineReplayDownloadRunning = true;
        bool mineDownloaded = DownloadMineReplayNow(g_LeaderboardDownloadForce, true);
        g_MineReplayDownloadRunning = false;
        if (!mineDownloaded) {
            g_LeaderboardDownloadStatus = "Failed: " + g_MineReplayDownloadStatus;
            WriteLeaderboardDownloadManifest(mapUid, mapId, mapName, rankFrom, rankTo, entries);
            g_LeaderboardDownloadRunning = false;
            return;
        }
        g_PipelineIncludeMineReplay = true;

        g_LeaderboardDownloadStatus = "Fetching leaderboard.";
        entries = FetchLeaderboardEntries(mapUid, rankFrom, rankTo);
        g_LeaderboardTotalCount = int(entries.Length);
        if (entries.Length == 0) {
            if (!g_LeaderboardDownloadStatus.StartsWith("Failed:")) {
                g_LeaderboardDownloadStatus = "Failed: leaderboard returned no entries.";
            }
            WriteLeaderboardDownloadManifest(mapUid, mapId, mapName, rankFrom, rankTo, entries);
            g_LeaderboardDownloadRunning = false;
            return;
        }

        g_LeaderboardDownloadStatus = "Resolving map id.";
        mapId = ResolveCachedMapId(mapUid);
        if (mapId.Length == 0) {
            g_LeaderboardDownloadStatus = "Failed: map id was not found for current map uid.";
            WriteLeaderboardDownloadManifest(mapUid, mapId, mapName, rankFrom, rankTo, entries);
            g_LeaderboardDownloadRunning = false;
            return;
        }

        g_LeaderboardDownloadStatus = "Resolving record URLs.";
        ResolveRecordUrls(entries, mapId);

        for (uint i = 0; i < entries.Length; i++) {
            LeaderboardRecordDownload@ entry = entries[i];
            g_LeaderboardDownloadStatus = "Downloading " + (i + 1) + " / " + entries.Length + ".";

            if (entry.recordUrl.Length == 0) {
                if (entry.error.Length == 0) {
                    entry.error = "Record URL is missing.";
                }
                g_LeaderboardFailedCount++;
                continue;
            }

            entry.filename = BuildLeaderboardRecordFileName(entry);
            entry.localPath = g_LeaderboardDownloadFolder + "/" + entry.filename;

            if (!g_LeaderboardDownloadForce && IO::FileExists(entry.localPath)) {
                entry.skippedExisting = true;
                g_LeaderboardSkippedCount++;
                continue;
            }

            Net::HttpRequest@ request = NadeoServices::Get(NadeoCoreAudience, entry.recordUrl);
            await(request.StartToFile(entry.localPath));
            if (RequestSucceeded(request)) {
                entry.downloaded = true;
                g_LeaderboardDownloadedCount++;
            } else {
                entry.error = "HTTP " + request.ResponseCode() + " " + request.Error();
                g_LeaderboardFailedCount++;
            }

            sleep(550);
        }

        WriteLeaderboardDownloadManifest(mapUid, mapId, mapName, rankFrom, rankTo, entries);
        g_PipelineReplayInputDirAuto = false;
        g_PipelineReplayInputDir = g_LeaderboardDownloadFolder;
        UpdatePipelineCommand();

        g_LeaderboardDownloadStatus = "Done: downloaded=" + g_LeaderboardDownloadedCount
            + " skipped=" + g_LeaderboardSkippedCount
            + " failed=" + g_LeaderboardFailedCount + ".";
    } catch {
        g_LeaderboardDownloadStatus = "Failed: unexpected download error.";
        g_MineReplayDownloadRunning = false;
        try {
            WriteLeaderboardDownloadManifest(mapUid, mapId, mapName, rankFrom, rankTo, entries);
        } catch {
        }
    }

    g_LeaderboardDownloadRunning = false;
}

string ValidateLeaderboardDownloadInput(const string &in mapUid, int rankFrom, int rankTo) {
    if (mapUid.Length == 0) {
        return "current map uid is not available.";
    }
    if (rankFrom < 1) {
        return "rank from must be at least 1.";
    }
    if (rankTo < rankFrom) {
        return "rank to must be greater than or equal to rank from.";
    }
    if (rankTo > PipelineMaxRank) {
        return "rank to cannot exceed " + PipelineMaxRank + ".";
    }
    if (rankTo - rankFrom > LeaderboardDownloadMaxRankDelta) {
        return "rank range is too large.";
    }
    return "";
}

bool WaitForNadeoLiveAuth() {
    for (uint i = 0; i < 100; i++) {
        if (NadeoServices::IsAuthenticated(NadeoLiveAudience)) {
            return true;
        }
        sleep(100);
    }
    return false;
}

array<LeaderboardRecordDownload@> FetchLeaderboardEntries(const string &in mapUid, int rankFrom, int rankTo) {
    array<LeaderboardRecordDownload@> entries;
    int length = rankTo - rankFrom + 1;
    int offset = rankFrom - 1;
    string url = "https://live-services.trackmania.nadeo.live/api/token/leaderboard/group/Personal_Best/map/"
        + Net::UrlEncode(mapUid)
        + "/top?onlyWorld=true&length=" + length
        + "&offset=" + offset;

    Net::HttpRequest@ request = NadeoServices::Get(NadeoLiveAudience, url);
    await(request.Start());
    if (!RequestSucceeded(request)) {
        g_LeaderboardDownloadStatus = "Failed: leaderboard HTTP " + request.ResponseCode() + " " + request.Error();
        return entries;
    }

    Json::Value@ root = request.Json();
    if (root is null || root.GetType() != Json::Type::Object) {
        return entries;
    }

    Json::Value@ tops = root.Get("tops");
    if (tops is null || tops.GetType() != Json::Type::Array || tops.Length == 0) {
        return entries;
    }

    Json::Value@ world = tops[0];
    if (world is null || world.GetType() != Json::Type::Object) {
        return entries;
    }

    Json::Value@ top = world.Get("top");
    if (top is null || top.GetType() != Json::Type::Array) {
        return entries;
    }

    for (uint i = 0; i < top.Length; i++) {
        Json::Value@ row = top[i];
        if (row is null || row.GetType() != Json::Type::Object) {
            continue;
        }

        LeaderboardRecordDownload@ entry = LeaderboardRecordDownload();
        entry.rank = JsonGetInt(row, "position");
        if (entry.rank == 0) {
            entry.rank = JsonGetInt(row, "rank");
        }
        if (entry.rank == 0) {
            entry.rank = rankFrom + int(i);
        }
        entry.accountId = JsonGetString(row, "accountId");
        entry.score = JsonGetInt(row, "score");
        entry.timestamp = JsonGetInt(row, "timestamp");
        if (entry.accountId.Length == 0) {
            entry.error = "Leaderboard entry accountId is missing.";
        }
        entries.InsertLast(entry);
    }

    return entries;
}

string ResolveCachedMapId(const string &in mapUid) {
    if (mapUid == g_MapIdCacheUid && g_MapIdCacheId.Length > 0) {
        return g_MapIdCacheId;
    }

    string mapId = FetchMapId(mapUid);
    if (mapId.Length > 0) {
        g_MapIdCacheUid = mapUid;
        g_MapIdCacheId = mapId;
    }
    return mapId;
}

void ResolveRecordUrls(array<LeaderboardRecordDownload@>@ entries, const string &in mapId) {
    string accountIds = "";
    for (uint i = 0; i < entries.Length; i++) {
        LeaderboardRecordDownload@ entry = entries[i];
        if (entry.accountId.Length == 0) {
            continue;
        }
        if (accountIds.Length > 0) {
            accountIds += ",";
        }
        accountIds += entry.accountId;
    }

    if (accountIds.Length == 0) {
        for (uint i = 0; i < entries.Length; i++) {
            entries[i].error = "No account id available.";
        }
        return;
    }

    string url = NadeoServices::BaseURLCore()
        + "/v2/mapRecords/by-account/?accountIdList=" + Net::UrlEncode(accountIds)
        + "&mapId=" + Net::UrlEncode(mapId);

    Net::HttpRequest@ request = NadeoServices::Get(NadeoCoreAudience, url);
    await(request.Start());
    if (!RequestSucceeded(request)) {
        string error = "Records HTTP " + request.ResponseCode() + " " + request.Error();
        for (uint i = 0; i < entries.Length; i++) {
            entries[i].error = error;
        }
        return;
    }

    Json::Value@ root = request.Json();
    if (root is null || root.GetType() != Json::Type::Array) {
        for (uint i = 0; i < entries.Length; i++) {
            entries[i].error = "Records response is not an array.";
        }
        return;
    }

    for (uint i = 0; i < root.Length; i++) {
        Json::Value@ record = root[i];
        if (record is null || record.GetType() != Json::Type::Object) {
            continue;
        }

        string accountId = JsonGetString(record, "accountId");
        LeaderboardRecordDownload@ entry = FindDownloadEntryByAccountId(entries, accountId);
        if (entry is null && i < entries.Length) {
            @entry = entries[i];
        }
        if (entry is null) {
            continue;
        }

        entry.mapRecordId = JsonGetString(record, "mapRecordId");
        if (entry.mapRecordId.Length == 0) {
            entry.mapRecordId = JsonGetString(record, "recordId");
        }
        entry.recordUrl = JsonGetString(record, "url");
        Json::Value@ scoreObj = record.Get("recordScore");
        if (scoreObj !is null && scoreObj.GetType() == Json::Type::Object) {
            int recordTime = JsonGetInt(scoreObj, "time");
            if (recordTime > 0) {
                entry.score = recordTime;
            }
        } else {
            int recordScore = JsonGetInt(record, "recordScore");
            if (recordScore > 0) {
                entry.score = recordScore;
            }
        }
    }

    for (uint i = 0; i < entries.Length; i++) {
        if (entries[i].recordUrl.Length == 0 && entries[i].error.Length == 0) {
            entries[i].error = "Record URL was not returned.";
        }
    }
}

LeaderboardRecordDownload@ FindDownloadEntryByAccountId(array<LeaderboardRecordDownload@>@ entries, const string &in accountId) {
    for (uint i = 0; i < entries.Length; i++) {
        if (entries[i].accountId == accountId) {
            return entries[i];
        }
    }
    return null;
}

string BuildLeaderboardRecordFileName(LeaderboardRecordDownload@ entry) {
    string score = entry.score > 0 ? "" + entry.score : "unknown";
    return "rank_" + entry.rank + "_" + SanitizePathSegment(entry.accountId) + "_" + score + ".Replay.Gbx";
}

string BuildLeaderboardDownloadStorageRelativeFolderPath(const string &in mapUid, int rankFrom, int rankTo) {
    string folder = SanitizePathSegment(mapUid);
    if (folder.Length == 0) {
        folder = "unknown_map";
    }
    return LeaderboardDownloadDirectory + "/" + folder + "/top_" + rankFrom + "_" + rankTo;
}

string BuildLeaderboardDownloadStoragePath(const string &in mapUid, int rankFrom, int rankTo) {
    return IO::FromStorageFolder(BuildLeaderboardDownloadStorageRelativeFolderPath(mapUid, rankFrom, rankTo));
}

string BuildCurrentLeaderboardDownloadStoragePath() {
    NormalizePipelineRange();
    return BuildLeaderboardDownloadStoragePath(g_CurrentMapUid, g_PipelineRangeFrom, g_PipelineRangeTo);
}

void WriteLeaderboardDownloadManifest(
    const string &in mapUid,
    const string &in mapId,
    const string &in mapName,
    int rankFrom,
    int rankTo,
    array<LeaderboardRecordDownload@>@ entries
) {
    if (g_LeaderboardDownloadFolder.Length == 0) {
        g_LeaderboardDownloadFolder = BuildLeaderboardDownloadStoragePath(mapUid, rankFrom, rankTo);
    }
    IO::CreateFolder(g_LeaderboardDownloadFolder, true);

    string path = g_LeaderboardDownloadFolder + "/manifest.json";
    IO::File file(path, IO::FileMode::Write);
    file.Write("{\n");
    file.Write("  \"schema_version\": 1,\n");
    file.Write("  \"map_uid\": \"" + JsonEscape(mapUid) + "\",\n");
    file.Write("  \"map_id\": \"" + JsonEscape(mapId) + "\",\n");
    file.Write("  \"map_name\": \"" + JsonEscape(mapName) + "\",\n");
    file.Write("  \"rank_from\": " + rankFrom + ",\n");
    file.Write("  \"rank_to\": " + rankTo + ",\n");
    file.Write("  \"created_at\": \"" + JsonEscape(Time::FormatStringUTC("%Y-%m-%dT%H:%M:%SZ", Time::Stamp)) + "\",\n");
    file.Write("  \"source\": \"nadeo_core_records\",\n");
    file.Write("  \"entries\": [\n");
    for (uint i = 0; i < entries.Length; i++) {
        LeaderboardRecordDownload@ entry = entries[i];
        file.Write("    {\n");
        file.Write("      \"rank\": " + entry.rank + ",\n");
        file.Write("      \"account_id\": \"" + JsonEscape(entry.accountId) + "\",\n");
        file.Write("      \"score\": " + entry.score + ",\n");
        file.Write("      \"timestamp\": " + entry.timestamp + ",\n");
        file.Write("      \"map_record_id\": \"" + JsonEscape(entry.mapRecordId) + "\",\n");
        file.Write("      \"record_url\": \"" + JsonEscape(entry.recordUrl) + "\",\n");
        file.Write("      \"filename\": \"" + JsonEscape(entry.filename) + "\",\n");
        file.Write("      \"local_path\": \"" + JsonEscape(entry.localPath) + "\",\n");
        file.Write("      \"downloaded\": " + (entry.downloaded ? "true" : "false") + ",\n");
        file.Write("      \"skipped_existing\": " + (entry.skippedExisting ? "true" : "false") + ",\n");
        if (entry.error.Length == 0) {
            file.Write("      \"error\": null\n");
        } else {
            file.Write("      \"error\": \"" + JsonEscape(entry.error) + "\"\n");
        }
        file.Write("    }" + (i + 1 < entries.Length ? "," : "") + "\n");
    }
    file.Write("  ]\n");
    file.Write("}\n");
    file.Close();
}
