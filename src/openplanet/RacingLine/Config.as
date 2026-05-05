string BundleRootDirectory = "bundles";
string MineReplayTmpDirectory = "tmp";
string LeaderboardDownloadDirectory = "downloads";
string DefaultBundleFileName = "top_1000_1010.analysis_bundle.json";
string PipelineProjectRoot = "E:/Projects/RacingLine";
int PipelineDefaultRangeFrom = 1000;
int PipelineDefaultRangeTo = 1010;
int PipelineMaxRank = 10000;
bool PipelineAutoSamples = true;
int PipelineManualSamples = 300;
int TrajectoryExportSampleMs = 100;

vec4 CenterLineColor = vec4(0.0f, 0.34f, 0.85f, 1.0f);
vec4 MineLineColor = vec4(1.0f, 0.2f, 0.2f, 1.0f);
vec4 OtherRunLineColor = vec4(0.95f, 0.95f, 0.95f, 0.25f);
vec4 ProblemZoneColor = vec4(1.0f, 0.7f, 0.0f, 1.0f);
vec4 SpeedDeltaPositiveColor = vec4(0.0f, 1.0f, 0.0f, 1.0f);
vec4 SpeedDeltaNegativeColor = vec4(1.0f, 0.0f, 0.0f, 1.0f);

float CenterLineWidth = 3.0f;
float MineLineWidth = 3.0f;
float OtherRunLineWidth = 1.0f;
float ProblemZoneMarkerSize = 8.0f;
int MaxVisibleProblemZones = 5;
bool ShowFullTrajectory = false;
float RenderDistance = 300.0f;
bool UseRouteWindow = true;
float RouteLookbehindDistance = 50.0f;
float RouteLookaheadDistance = 300.0f;
float RouteReacquireDistance = 120.0f;
int RouteAnchorBackSearchPoints = 80;
int RouteAnchorForwardSearchPoints = 180;

vec4 DebugPointColor = vec4(0.1f, 0.8f, 1.0f, 1.0f);
float DebugPointRadius = 3.0f;
int DebugPointStride = 5;
