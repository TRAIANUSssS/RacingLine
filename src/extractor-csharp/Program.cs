using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using GBX.NET;
using GBX.NET.Engines.Game;
using GBX.NET.Engines.Plug;
using GBX.NET.Engines.Scene;
using GBX.NET.LZO;
using GBX.NET.ZLib;

Gbx.LZO = new Lzo();
Gbx.ZLib = new ZLib();

var repositoryRoot = FindRepositoryRoot(Environment.CurrentDirectory);
var defaultReplayDirectory = Path.Combine(repositoryRoot, "data", "raw", "replays");
var defaultOutputRootDirectory = Path.Combine(repositoryRoot, "data", "raw", "trajectories");

var jsonOptions = new JsonSerializerOptions
{
    WriteIndented = true
};

try
{
    if (args.Length > 0 && File.Exists(args[0]))
    {
        var singleOutputPath = args.Length > 1
            ? args[1]
            : Path.Combine(
                Path.GetDirectoryName(args[0]) ?? Environment.CurrentDirectory,
                $"{Path.GetFileNameWithoutExtension(args[0])}.trajectory.json");

        var singleResult = ProcessReplayFile(args[0], singleOutputPath, jsonOptions);
        PrintSingleResult(singleResult);
        return;
    }

    if (!Directory.Exists(defaultReplayDirectory))
    {
        Console.WriteLine($"Replay directory not found: {defaultReplayDirectory}");
        return;
    }

    Directory.CreateDirectory(defaultOutputRootDirectory);

    var replayFiles = Directory
        .GetFiles(defaultReplayDirectory, "*.Replay.Gbx", SearchOption.AllDirectories)
        .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
        .ToArray();

    if (replayFiles.Length == 0)
    {
        Console.WriteLine($"No replay files found in: {defaultReplayDirectory}");
        return;
    }

    var mapDirectoriesByKey = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    var mapCounter = 1;
    var results = new List<ExportResult>(replayFiles.Length);

    foreach (var replayFile in replayFiles)
    {
        var exportPreview = ExtractReplayData(replayFile);
        if (!exportPreview.Success)
        {
            results.Add(exportPreview);
            continue;
        }

        var mapKey = string.IsNullOrWhiteSpace(exportPreview.MapKey)
            ? $"map_{mapCounter}"
            : exportPreview.MapKey;

        if (!mapDirectoriesByKey.TryGetValue(mapKey, out var mapDirectoryName))
        {
            mapDirectoryName = CreateMapDirectoryName(exportPreview.MapName, mapCounter);
            mapDirectoriesByKey[mapKey] = mapDirectoryName;
            mapCounter++;
        }

        var mapDirectoryPath = Path.Combine(defaultOutputRootDirectory, mapDirectoryName);
        var outputPath = Path.Combine(
            mapDirectoryPath,
            $"{Path.GetFileNameWithoutExtension(replayFile)}.trajectory.json");

        Directory.CreateDirectory(mapDirectoryPath);

        File.WriteAllText(outputPath, JsonSerializer.Serialize(exportPreview.Points, jsonOptions));

        results.Add(exportPreview with
        {
            OutputPath = outputPath
        });
    }

    PrintBatchSummary(defaultReplayDirectory, defaultOutputRootDirectory, results);
}
catch (Exception ex)
{
    Console.WriteLine("Trajectory export failed.");
    Console.WriteLine(ex.Message);
}

static ExportResult ProcessReplayFile(string inputPath, string outputPath, JsonSerializerOptions jsonOptions)
{
    var result = ExtractReplayData(inputPath);
    if (!result.Success)
    {
        return result;
    }

    var outputDirectory = Path.GetDirectoryName(outputPath);
    if (!string.IsNullOrWhiteSpace(outputDirectory))
    {
        Directory.CreateDirectory(outputDirectory);
    }

    File.WriteAllText(outputPath, JsonSerializer.Serialize(result.Points, jsonOptions));

    return result with
    {
        OutputPath = outputPath
    };
}

static ExportResult ExtractReplayData(string inputPath)
{
    try
    {
        var node = Gbx.ParseNode(inputPath);
        if (node is null)
        {
            return ExportResult.Fail(inputPath, "Failed to parse GBX: parser returned null.");
        }

        var ghost = node switch
        {
            CGameCtnReplayRecord replay => replay.GetGhosts().FirstOrDefault(),
            CGameCtnMediaClip clip => clip.GetGhosts().FirstOrDefault(),
            CGameCtnGhost g => g,
            _ => null
        };

        if (ghost is null)
        {
            return ExportResult.Fail(inputPath, "Ghost not found in this replay.");
        }

        if (ghost.RecordData is not CPlugEntRecordData recordData)
        {
            return ExportResult.Fail(inputPath, "RecordData is missing or has an unexpected type.");
        }

        if (recordData.EntList is null || recordData.EntList.Count == 0 || recordData.EntList[0] is null)
        {
            return ExportResult.Fail(inputPath, "EntList is missing or does not contain EntList[0].");
        }

        var samples = recordData.EntList[0]!.Samples;
        if (samples is null || samples.Count == 0)
        {
            return ExportResult.Fail(inputPath, "EntList[0].Samples is missing or empty.");
        }

        var points = ExtractTrajectoryPoints(samples);
        if (points.Count == 0)
        {
            return ExportResult.Fail(inputPath, "No valid trajectory points were extracted from EntList[0].Samples.");
        }

        var mapName = TryResolveMapName(node) ?? Path.GetFileNameWithoutExtension(inputPath);
        var mapKey = SanitizeForPath(mapName);

        return new ExportResult(
            InputPath: inputPath,
            OutputPath: null,
            Success: true,
            Error: null,
            Points: points,
            MapName: mapName,
            MapKey: string.IsNullOrWhiteSpace(mapKey) ? null : mapKey);
    }
    catch (Exception ex)
    {
        return ExportResult.Fail(inputPath, ex.Message);
    }
}

static List<TrajectoryPoint> ExtractTrajectoryPoints(IReadOnlyList<CPlugEntRecordData.EntRecordDelta> samples)
{
    var points = new List<TrajectoryPoint>(samples.Count);

    foreach (var sample in samples)
    {
        if (sample is not CSceneVehicleVis.EntRecordDelta vehicleSample)
        {
            continue;
        }

        var position = vehicleSample.Position;
        var time = vehicleSample.Time;

        points.Add(new TrajectoryPoint(
            t: time.TotalMilliseconds,
            x: position.X,
            y: position.Y,
            z: position.Z,
            speed: vehicleSample.Speed));
    }

    return points;
}

static string? TryResolveMapName(GBX.NET.Engines.MwFoundations.CMwNod node)
{
    if (node is CGameCtnReplayRecord replay)
    {
        return FirstNonEmpty(
            TryGetNestedStringProperty(replay, "MapInfo", "Name"),
            TryGetNestedStringProperty(replay, "MapInfo", "MapUid"),
            TryGetNestedStringProperty(replay, "Challenge", "MapName"),
            TryGetNestedStringProperty(replay, "Challenge", "Name"),
            TryGetNestedStringProperty(replay, "Challenge", "MapUid"),
            TryGetStringProperty(replay, "PlayerNickname"));
    }

    if (node is CGameCtnGhost ghost)
    {
        return FirstNonEmpty(
            TryGetStringProperty(ghost, "GhostNickname"),
            TryGetStringProperty(ghost, "GhostLogin"));
    }

    return null;
}

static string? TryGetNestedStringProperty(object obj, string parentPropertyName, string childPropertyName)
{
    var parent = GetPropertyValue(obj, parentPropertyName);
    return parent is null ? null : TryGetStringProperty(parent, childPropertyName);
}

static string? TryGetStringProperty(object obj, string propertyName)
{
    var value = GetPropertyValue(obj, propertyName);
    if (value is null)
    {
        return null;
    }

    var text = value.ToString();
    return string.IsNullOrWhiteSpace(text) ? null : text.Trim();
}

static object? GetPropertyValue(object obj, string propertyName)
{
    try
    {
        var prop = obj.GetType().GetProperty(propertyName);
        if (prop is null || prop.GetIndexParameters().Length > 0)
        {
            return null;
        }

        return prop.GetValue(obj);
    }
    catch
    {
        return null;
    }
}

static string FirstNonEmpty(params string?[] values)
{
    foreach (var value in values)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value;
        }
    }

    return string.Empty;
}

static string CreateMapDirectoryName(string? mapName, int mapCounter)
{
    var sanitized = SanitizeForPath(mapName);
    return string.IsNullOrWhiteSpace(sanitized)
        ? $"map_{mapCounter}"
        : sanitized;
}

static string SanitizeForPath(string? value)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        return string.Empty;
    }

    var invalidChars = Path.GetInvalidFileNameChars();
    var sanitizedChars = value
        .Trim()
        .Select(ch => invalidChars.Contains(ch) ? '_' : ch)
        .ToArray();

    var sanitized = new string(sanitizedChars)
        .Replace('.', '_')
        .Trim();

    while (sanitized.Contains("  ", StringComparison.Ordinal))
    {
        sanitized = sanitized.Replace("  ", " ", StringComparison.Ordinal);
    }

    return sanitized;
}

static string FindRepositoryRoot(string startDirectory)
{
    var directory = new DirectoryInfo(Path.GetFullPath(startDirectory));

    while (directory is not null)
    {
        if (directory.GetFiles("RacingLine.sln").Length > 0)
        {
            return directory.FullName;
        }

        directory = directory.Parent;
    }

    return Path.GetFullPath(startDirectory);
}

static void PrintSingleResult(ExportResult result)
{
    if (!result.Success)
    {
        Console.WriteLine(result.Error);
        return;
    }

    Console.WriteLine($"Points exported: {result.Points.Count}");
    Console.WriteLine($"Saved to: {result.OutputPath}");

    foreach (var point in result.Points.Take(3))
    {
        Console.WriteLine($"t={point.t}, x={point.x}, y={point.y}, z={point.z}, speed={point.speed}");
    }
}

static void PrintBatchSummary(string replayDirectory, string outputRootDirectory, IReadOnlyList<ExportResult> results)
{
    var succeeded = results.Where(r => r.Success).ToList();
    var failed = results.Where(r => !r.Success).ToList();

    Console.WriteLine($"Replay directory: {replayDirectory}");
    Console.WriteLine($"Output root: {outputRootDirectory}");
    Console.WriteLine($"Processed: {results.Count}");
    Console.WriteLine($"Succeeded: {succeeded.Count}");
    Console.WriteLine($"Failed: {failed.Count}");

    foreach (var result in succeeded)
    {
        Console.WriteLine();
        Console.WriteLine($"OK: {Path.GetFileName(result.InputPath)}");
        Console.WriteLine($"Map: {result.MapName}");
        Console.WriteLine($"Points: {result.Points.Count}");
        Console.WriteLine($"Saved to: {result.OutputPath}");
    }

    foreach (var result in failed)
    {
        Console.WriteLine();
        Console.WriteLine($"FAIL: {Path.GetFileName(result.InputPath)}");
        Console.WriteLine(result.Error);
    }
}

public readonly record struct TrajectoryPoint(double t, float x, float y, float z, float speed);

public sealed record ExportResult(
    string InputPath,
    string? OutputPath,
    bool Success,
    string? Error,
    IReadOnlyList<TrajectoryPoint> Points,
    string? MapName,
    string? MapKey)
{
    public static ExportResult Fail(string inputPath, string error)
    {
        return new ExportResult(
            InputPath: inputPath,
            OutputPath: null,
            Success: false,
            Error: error,
            Points: Array.Empty<TrajectoryPoint>(),
            MapName: null,
            MapKey: null);
    }
}
