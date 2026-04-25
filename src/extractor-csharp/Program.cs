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
var options = ExtractorOptions.Parse(args, defaultReplayDirectory, defaultOutputRootDirectory);

var jsonOptions = new JsonSerializerOptions
{
    WriteIndented = true
};

try
{
    if (options.HelpRequested)
    {
        PrintUsage();
        return;
    }

    if (options.SingleReplayPath is not null)
    {
        var singleOutputPath = options.SingleOutputPath is not null
            ? options.SingleOutputPath
            : Path.Combine(
                Path.GetDirectoryName(options.SingleReplayPath) ?? Environment.CurrentDirectory,
                $"{Path.GetFileNameWithoutExtension(options.SingleReplayPath)}.trajectory.json");

        var singleResult = ProcessReplayFile(options.SingleReplayPath, singleOutputPath, jsonOptions);
        PrintSingleResult(singleResult);
        return;
    }

    if (!Directory.Exists(options.ReplayDirectory))
    {
        Console.WriteLine($"Replay directory not found: {options.ReplayDirectory}");
        return;
    }

    Directory.CreateDirectory(options.OutputRootDirectory);

    var replayFiles = GetInputGbxFiles(options.ReplayDirectory, options.Recursive);

    if (replayFiles.Length == 0)
    {
        Console.WriteLine($"No replay or ghost files found in: {options.ReplayDirectory}");
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

        var mapDirectoryName = options.MapName;
        if (string.IsNullOrWhiteSpace(mapDirectoryName) && !mapDirectoriesByKey.TryGetValue(mapKey, out mapDirectoryName))
        {
            mapDirectoryName = CreateMapDirectoryName(exportPreview.MapName, mapCounter);
            mapDirectoriesByKey[mapKey] = mapDirectoryName;
            mapCounter++;
        }

        var mapDirectoryPath = Path.Combine(options.OutputRootDirectory, mapDirectoryName);
        var outputFileStem = CreateOutputFileStem(options.MapName, replayFile);
        var outputPath = Path.Combine(
            mapDirectoryPath,
            $"{outputFileStem}.trajectory.json");

        Directory.CreateDirectory(mapDirectoryPath);

        File.WriteAllText(outputPath, JsonSerializer.Serialize(exportPreview.Points, jsonOptions));

        results.Add(exportPreview with
        {
            OutputPath = outputPath
        });
    }

    PrintBatchSummary(options.ReplayDirectory, options.OutputRootDirectory, results);
}
catch (Exception ex)
{
    Console.WriteLine("Trajectory export failed.");
    Console.WriteLine(ex.Message);
}

static void PrintUsage()
{
    Console.WriteLine("Usage:");
    Console.WriteLine("  dotnet run --project src/extractor-csharp/RacingLine.csproj -- [options]");
    Console.WriteLine("  dotnet run --project src/extractor-csharp/RacingLine.csproj -- <replay-file> [output-json]");
    Console.WriteLine();
    Console.WriteLine("Options:");
    Console.WriteLine("  --replay-dir <path>   Directory containing .Replay.Gbx or .Ghost.Gbx files.");
    Console.WriteLine("  --output-root <path>  Root directory for trajectory JSON output.");
    Console.WriteLine("  --map <name>          Force all batch output into this map folder.");
    Console.WriteLine("  --recursive           Include replay files from nested directories.");
}

static string[] GetInputGbxFiles(string replayDirectory, bool recursive)
{
    var searchOption = recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
    var patterns = new[]
    {
        "*.Replay.Gbx",
        "*.Ghost.Gbx"
    };

    var files = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (var pattern in patterns)
    {
        foreach (var file in Directory.GetFiles(replayDirectory, pattern, searchOption))
        {
            files.Add(file);
        }
    }

    return files
        .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
        .ToArray();
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

        if (recordData.EntList is null || recordData.EntList.Count == 0)
        {
            return ExportResult.Fail(inputPath, "EntList is missing or empty.");
        }

        var points = ExtractBestTrajectoryPoints(recordData.EntList);
        if (points.Count == 0)
        {
            return ExportResult.Fail(inputPath, "No valid trajectory points were extracted from any EntList samples.");
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

static List<TrajectoryPoint> ExtractBestTrajectoryPoints(
    IReadOnlyList<CPlugEntRecordData.EntRecordListElem> entList)
{
    var bestPoints = new List<TrajectoryPoint>();

    foreach (var entRecord in entList)
    {
        var samples = entRecord?.Samples;
        if (samples is null || samples.Count == 0)
        {
            continue;
        }

        var points = ExtractTrajectoryPoints(samples);
        if (points.Count > bestPoints.Count)
        {
            bestPoints = points;
        }
    }

    return bestPoints;
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

static string CreateOutputFileStem(string? forcedMapName, string inputPath)
{
    var inputStem = Path.GetFileNameWithoutExtension(inputPath);
    if (string.IsNullOrWhiteSpace(forcedMapName))
    {
        return inputStem;
    }

    var prefix = $"{forcedMapName}_";
    return inputStem.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
        ? inputStem
        : $"{prefix}{inputStem}";
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

public sealed record ExtractorOptions(
    string ReplayDirectory,
    string OutputRootDirectory,
    string? MapName,
    string? SingleReplayPath,
    string? SingleOutputPath,
    bool Recursive,
    bool HelpRequested)
{
    public static ExtractorOptions Parse(
        string[] args,
        string defaultReplayDirectory,
        string defaultOutputRootDirectory)
    {
        if (args.Length > 0 && File.Exists(args[0]))
        {
            return new ExtractorOptions(
                ReplayDirectory: defaultReplayDirectory,
                OutputRootDirectory: defaultOutputRootDirectory,
                MapName: null,
                SingleReplayPath: Path.GetFullPath(args[0]),
                SingleOutputPath: args.Length > 1 ? Path.GetFullPath(args[1]) : null,
                Recursive: false,
                HelpRequested: false);
        }

        var replayDirectory = defaultReplayDirectory;
        var outputRootDirectory = defaultOutputRootDirectory;
        string? mapName = null;
        var recursive = false;
        var helpRequested = false;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            switch (arg)
            {
                case "--help":
                case "-h":
                    helpRequested = true;
                    break;
                case "--replay-dir":
                    replayDirectory = RequireValue(args, ref i, arg);
                    break;
                case "--output-root":
                    outputRootDirectory = RequireValue(args, ref i, arg);
                    break;
                case "--map":
                    mapName = RequireValue(args, ref i, arg);
                    break;
                case "--recursive":
                    recursive = true;
                    break;
                default:
                    throw new ArgumentException($"Unknown argument: {arg}");
            }
        }

        return new ExtractorOptions(
            ReplayDirectory: Path.GetFullPath(replayDirectory),
            OutputRootDirectory: Path.GetFullPath(outputRootDirectory),
            MapName: mapName,
            SingleReplayPath: null,
            SingleOutputPath: null,
            Recursive: recursive,
            HelpRequested: helpRequested);
    }

    private static string RequireValue(string[] args, ref int index, string optionName)
    {
        if (index + 1 >= args.Length)
        {
            throw new ArgumentException($"Missing value for {optionName}");
        }

        index++;
        return args[index];
    }
}
